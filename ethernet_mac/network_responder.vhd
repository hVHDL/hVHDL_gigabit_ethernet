library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;

-- An address on the network for an FPGA, between ethernet_mac's streams: frames from its receive
-- stream (rx_clock), replies into its transmit stream (clock).
--
--   ARP   a request for own_ip gets a reply with own_address
--   ICMP  an echo request to own_address and own_ip gets an echo reply (ping)
--   UDP   a datagram to own_address, own_ip and udp_echo_port goes back to its sender
--   raw   a frame with g_raw_ethertype goes back to its sender (a test without IP)
--   user  a datagram to own_address, own_ip and udp_user_port is handed over: its payload on
--         user_t*, its sender on user_source_* (held from the first byte to the last), its
--         length on user_length - a UDP endpoint for the application (udp_sender answers)
-- IPv4 is answered with version 4 and no options, not fragmented, with a good header checksum.
-- Everything else is ignored. ethernet_mac has already dropped frames with a bad CRC or length
-- and frames for other addresses (broadcast passes, for ARP).
--
-- A frame goes into a buffer as it comes, and its first 42 bytes - the Ethernet, ARP, IPv4 and
-- ICMP/UDP headers - are kept on the way. A reply is its request with a few fields changed, so it
-- is sent from the buffer behind a reply header made from those 42 bytes:
--   all   destination = the sender, source = own_address
--   ARP   opcode 2, sender = own_address / own_ip, target = the requester
--   ICMP  the IP addresses swapped, type 0, the ICMP checksum updated (RFC 1624)
--   UDP   the IP addresses and the ports swapped
-- Swapping two fields of a ones' complement sum leaves the sum as it is, so the request's IP
-- header checksum and UDP checksum stay right. A reply has its request's length.
--
-- One frame at a time: while a reply goes out, s_tready is low and new frames wait in
-- ethernet_mac's receive FIFO. The reply is given without gaps once its first byte is taken, as
-- ethernet_mac_tx needs. The kept header and the frame's length cross to clock held by a toggle
-- handshake (constrain rx_clock -> clock as asynchronous); the buffer is a simple dual port RAM
-- with a write port in rx_clock and a read port in clock.
--
-- configuration in clock, quasi static (taken into rx_clock with cdc_snapshot); counters, each a
-- clock pulse in clock: arp_replied, icmp_replied, udp_replied, raw_echoed, user_received, ignored.
entity network_responder is
    generic(
        g_buffer_bytes  : positive := 2048;   -- a power of two, more than a frame without its FCS
        g_raw_ethertype : std_logic_vector(15 downto 0) := test_frame_ethertype
    );
    port(
        rx_clock      : in std_logic;
        s_tvalid      : in std_logic;
        s_tready      : out std_logic;
        s_tdata       : in std_logic_vector(7 downto 0);
        s_tlast       : in std_logic;

        clock         : in std_logic;
        m_tvalid      : out std_logic;
        m_tready      : in std_logic;
        m_tdata       : out std_logic_vector(7 downto 0);
        m_tlast       : out std_logic;

        own_address   : in std_logic_vector(47 downto 0);  -- byte 0 (first on the wire) in bits 7:0
        own_ip        : in std_logic_vector(31 downto 0);  -- byte 0 (first on the wire) in bits 7:0
        udp_echo_port : in std_logic_vector(15 downto 0);  -- the port number
        udp_user_port : in std_logic_vector(15 downto 0) := x"0000";   -- 0: none

        -- datagrams to udp_user_port, in clock
        user_tvalid         : out std_logic;
        user_tready         : in std_logic := '1';
        user_tdata          : out std_logic_vector(7 downto 0);
        user_tlast          : out std_logic;
        user_length         : out natural range 0 to 2047;          -- payload bytes
        user_source_address : out std_logic_vector(47 downto 0);    -- byte 0 in bits 7:0
        user_source_ip      : out std_logic_vector(31 downto 0);    -- byte 0 in bits 7:0
        user_source_port    : out std_logic_vector(15 downto 0);

        arp_replied   : out boolean;
        icmp_replied  : out boolean;
        udp_replied   : out boolean;
        raw_echoed    : out boolean;
        user_received : out boolean;
        ignored       : out boolean
    );
end entity network_responder;

architecture rtl of network_responder is

    constant header_length : natural := 42;    -- up to the end of an ARP message or the UDP header
    type byte_array is array (natural range <>) of byte;
    subtype header_array is byte_array(0 to header_length-1);

    type kinds is (none, raw, arp, icmp, udp, user);

    function field(bytes : header_array; first, count : natural) return std_logic_vector is
        variable value : std_logic_vector(8*count-1 downto 0);
    begin
        for i in 0 to count-1 loop
            value(8*(count-i)-1 downto 8*(count-i-1)) := bytes(first+i);
        end loop;
        return value;   -- the first byte in the top bits, as numbers are sent
    end function;

    -- byte i of an address given with byte 0 in bits 7:0
    function address_byte(address : std_logic_vector; i : natural) return byte is
        variable a : std_logic_vector(address'length-1 downto 0) := address;
    begin
        return a(8*i+7 downto 8*i);
    end function;

    function is_address(bytes : header_array; first : natural; address : std_logic_vector) return boolean is
    begin
        for i in 0 to address'length/8-1 loop
            if bytes(first+i) /= address_byte(address, i) then
                return false;
            end if;
        end loop;
        return true;
    end function;

    -- ones' complement: the carries of a sum folded into 16 bits
    function fold(sum : unsigned) return unsigned is
        variable s : unsigned(19 downto 0) := resize(sum, 20);
    begin
        s := resize(s(15 downto 0), 20) + resize(s(19 downto 16), 20);
        s := resize(s(15 downto 0), 20) + resize(s(19 downto 16), 20);
        return s(15 downto 0);
    end function;

    constant ethertype_arp  : std_logic_vector(15 downto 0) := x"0806";
    constant ethertype_ipv4 : std_logic_vector(15 downto 0) := x"0800";
    -- ARP bytes 14..21 of a request: Ethernet, IPv4, 6 and 4 byte addresses, opcode 1
    constant arp_request    : std_logic_vector(63 downto 0) := x"0001080006040001";

    -- byte i of an address given with byte 0 in bits 7:0, the other way round
    function from_header(bytes : header_array; first, count : natural) return std_logic_vector is
        variable value : std_logic_vector(8*count-1 downto 0);
    begin
        for i in 0 to count-1 loop
            value(8*i+7 downto 8*i) := bytes(first+i);
        end loop;
        return value;
    end function;

    -- configuration in rx_clock
    signal config, rx_config : std_logic_vector(111 downto 0);
    alias rx_address   : std_logic_vector(47 downto 0) is rx_config(111 downto 64);
    alias rx_ip        : std_logic_vector(31 downto 0) is rx_config(63 downto 32);
    alias rx_port      : std_logic_vector(15 downto 0) is rx_config(31 downto 16);
    alias rx_user_port : std_logic_vector(15 downto 0) is rx_config(15 downto 0);

    -- buffer
    type buffer_array is array (0 to g_buffer_bytes-1) of byte;
    signal frame_buffer : buffer_array;
    signal write_enable  : boolean := false;
    signal write_address : natural range 0 to g_buffer_bytes-1 := 0;
    signal write_data    : byte := (others => '0');
    signal read_address  : natural range 0 to g_buffer_bytes-1;
    signal read_data     : byte := (others => '0');

    -- receive side, rx_clock
    signal receiving   : boolean := true;
    signal index       : natural range 0 to g_buffer_bytes := 0;
    signal header      : header_array := (others => (others => '0'));
    signal high_byte   : byte := (others => '0');
    signal ip_sum      : unsigned(19 downto 0) := (others => '0');
    signal kind        : kinds := none;
    signal length      : natural range 0 to g_buffer_bytes := 0;      -- the frame's, or the payload's end
    signal icmp_sum    : std_logic_vector(15 downto 0) := (others => '0');
    signal request     : std_logic := '0';
    signal done_meta, done_sync, done_seen : std_logic := '0';
    signal rx_ignored  : boolean := false;

    -- transmit side, clock: a reply on m_t*, or a user datagram's payload on user_t*
    type tx_states is (idle, preparing, sending, delivering);
    signal tx_state    : tx_states := idle;
    signal request_meta, request_sync, request_seen : std_logic := '0';
    signal done        : std_logic := '0';
    signal reply_kind  : kinds := none;
    signal reply       : header_array := (others => (others => '0'));
    signal first       : natural range 0 to g_buffer_bytes-1 := 0;
    signal last        : natural range 0 to g_buffer_bytes := 0;
    signal shown       : natural range 0 to g_buffer_bytes-1 := 0;   -- the byte on m_tdata

    attribute async_reg : boolean;
    attribute async_reg of done_meta, done_sync, request_meta, request_sync : signal is true;

begin

    config <= own_address & own_ip & udp_echo_port & udp_user_port;

    u_config_crossing : entity work.cdc_snapshot
    generic map(g_width => 112)
    port map(
        source_clock       => clock
        ,source_data       => config
        ,destination_clock => rx_clock
        ,destination_data  => rx_config
    );

------------------------------------------------------------------------
    -- receive: the frame into the buffer, the headers kept, the decision at its last byte
    s_tready <= '1' when receiving else '0';

    receive : process(rx_clock)
        variable ip_ok : boolean;
        variable sum   : unsigned(16 downto 0);
        variable this  : kinds;
        variable udp_bytes : natural range 0 to 65535;
    begin
        if rising_edge(rx_clock) then
            done_meta    <= done;
            done_sync    <= done_meta;
            write_enable <= false;
            rx_ignored   <= false;

            if receiving then
                if s_tvalid = '1' then
                    if index < g_buffer_bytes then
                        write_enable  <= true;
                        write_address <= index;
                        write_data    <= s_tdata;
                    end if;
                    if index < header_length then
                        header(index) <= s_tdata;
                    end if;
                    -- the IPv4 header checksum over the 16 bit words of bytes 14..33
                    if index >= 14 and index <= 33 then
                        if index mod 2 = 0 then
                            high_byte <= s_tdata;
                        elsif index = 15 then
                            ip_sum <= resize(unsigned(high_byte) & unsigned(s_tdata), 20);
                        else
                            ip_sum <= ip_sum + (unsigned(high_byte) & unsigned(s_tdata));
                        end if;
                    end if;

                    if s_tlast = '1' then
                        index <= 0;
                        -- ethernet_mac passes 60 bytes and more: the headers are all in
                        ip_ok := field(header, 12, 2) = ethertype_ipv4
                                 and header(14) = x"45"
                                 and field(header, 20, 2)(13 downto 0) = "00" & x"000"   -- MF 0, offset 0
                                 and fold(ip_sum) = x"FFFF"
                                 and is_address(header, 0, rx_address)
                                 and is_address(header, 30, rx_ip);
                        this := none;
                        if field(header, 12, 2) = g_raw_ethertype then
                            this := raw;
                        elsif field(header, 12, 2) = ethertype_arp and field(header, 14, 8) = arp_request
                                and is_address(header, 38, rx_ip) then
                            this := arp;
                        elsif ip_ok and header(23) = x"01" and header(34) = x"08" then
                            this := icmp;
                        elsif ip_ok and header(23) = x"11" and field(header, 36, 2) = rx_port then
                            this := udp;
                        elsif ip_ok and header(23) = x"11" and field(header, 36, 2) = rx_user_port
                                and rx_user_port /= x"0000" then
                            this := user;
                        end if;
                        -- a user datagram's payload ends where its UDP length says (a short one
                        -- comes padded to 60 bytes); one without payload or cut short is ignored
                        udp_bytes := to_integer(unsigned(field(header, 38, 2)));
                        if this = user and (udp_bytes <= 8 or 34 + udp_bytes > index + 1) then
                            this := none;
                        end if;

                        if this /= none and index < g_buffer_bytes then
                            kind      <= this;
                            if this = user then
                                length <= 34 + udp_bytes;
                            else
                                length <= index + 1;
                            end if;
                            -- ICMP type 8 -> 0: HC' = ~(~HC + ~m + m'), m = 0x0800, m' = 0
                            sum       := resize(not unsigned(field(header, 36, 2)), 17) + x"F7FF";
                            icmp_sum  <= not std_logic_vector(fold(sum));
                            request   <= not request;
                            receiving <= false;
                        else
                            rx_ignored <= true;
                        end if;
                    elsif index < g_buffer_bytes then
                        index <= index + 1;
                    end if;
                end if;
            elsif done_sync /= done_seen then
                -- the reply has gone: the next frame (header, kind and length were held till now)
                done_seen <= done_sync;
                receiving <= true;
            end if;
        end if;
    end process;

    write_buffer : process(rx_clock)
    begin
        if rising_edge(rx_clock) then
            if write_enable then
                frame_buffer(write_address) <= write_data;
            end if;
        end if;
    end process;

    read_buffer : process(clock)
    begin
        if rising_edge(clock) then
            read_data <= frame_buffer(read_address);
        end if;
    end process;

------------------------------------------------------------------------
    -- transmit: the reply header, then the rest of the frame from the buffer; or a user
    -- datagram's payload from the buffer. read_data always holds frame_buffer(shown): the next
    -- address is chosen before the clock (preparing fetches the first byte).
    m_tvalid <= '1' when tx_state = sending else '0';
    m_tdata  <= reply(shown) when shown < header_length else read_data;
    m_tlast  <= '1' when tx_state = sending and shown = last else '0';

    user_tvalid <= '1' when tx_state = delivering else '0';
    user_tdata  <= read_data;
    user_tlast  <= '1' when tx_state = delivering and shown = last else '0';
    user_length <= last - header_length + 1 when last >= header_length else 0;
    user_source_address <= from_header(header, 6, 6);
    user_source_ip      <= from_header(header, 26, 4);
    user_source_port    <= field(header, 34, 2);

    read_address <= first     when tx_state = idle or tx_state = preparing else
                    shown + 1 when tx_state = sending and m_tready = '1' and shown /= last else
                    shown + 1 when tx_state = delivering and user_tready = '1' and shown /= last else
                    shown;

    transmit : process(clock)
        variable r : header_array;
    begin
        if rising_edge(clock) then
            request_meta  <= request;
            request_sync  <= request_meta;
            arp_replied   <= false;
            icmp_replied  <= false;
            udp_replied   <= false;
            raw_echoed    <= false;
            user_received <= false;
            shown         <= read_address;

            CASE tx_state is
                WHEN idle =>
                    first <= 0;
                    if request_sync /= request_seen then
                        request_seen <= request_sync;
                        -- the reply header from the request's: kind, header and length are held
                        r := header;
                        for i in 0 to 5 loop
                            r(i)   := header(6+i);                       -- to the sender
                            r(6+i) := address_byte(own_address, i);      -- from us
                        end loop;
                        CASE kind is
                            WHEN arp =>
                                r(21) := x"02";                          -- a reply
                                for i in 0 to 5 loop
                                    r(22+i) := address_byte(own_address, i);
                                    r(32+i) := header(22+i);
                                end loop;
                                for i in 0 to 3 loop
                                    r(28+i) := header(38+i);             -- own_ip, as asked for
                                    r(38+i) := header(28+i);
                                end loop;
                            WHEN icmp | udp =>
                                for i in 0 to 3 loop
                                    r(26+i) := header(30+i);
                                    r(30+i) := header(26+i);
                                end loop;
                                if kind = icmp then
                                    r(34) := x"00";                      -- echo reply
                                    r(36) := icmp_sum(15 downto 8);
                                    r(37) := icmp_sum(7 downto 0);
                                else
                                    r(34 to 35) := header(36 to 37);     -- the ports swapped
                                    r(36 to 37) := header(34 to 35);
                                end if;
                            WHEN others =>
                                null;
                        end CASE;
                        reply      <= r;
                        reply_kind <= kind;
                        last       <= length - 1;
                        if kind = user then
                            first <= header_length;
                        end if;
                        tx_state   <= preparing;
                    end if;

                WHEN preparing =>                                -- buffer(first) is read now
                    if reply_kind = user then
                        tx_state <= delivering;
                    else
                        tx_state <= sending;
                    end if;

                WHEN sending =>
                    if m_tready = '1' and shown = last then
                        tx_state <= idle;
                        done     <= not done;
                        CASE reply_kind is
                            WHEN arp    => arp_replied  <= true;
                            WHEN icmp   => icmp_replied <= true;
                            WHEN udp    => udp_replied  <= true;
                            WHEN raw    => raw_echoed   <= true;
                            WHEN others => null;
                        end CASE;
                    end if;

                WHEN delivering =>
                    if user_tready = '1' and shown = last then
                        tx_state      <= idle;
                        done          <= not done;
                        user_received <= true;
                    end if;
            end CASE;
        end if;
    end process;

    -- the ignored frames' pulses come at most one a frame, far enough apart for cdc_pulse
    u_ignored : entity work.cdc_pulse port map(rx_clock, rx_ignored, clock, ignored);

end architecture rtl;
