library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;

-- UDP datagrams from the FPGA: a payload from s_t* becomes an Ethernet frame with an IPv4 and a
-- UDP header on m_t*, for ethernet_mac's transmit stream (or a frame_mux in front of it).
--
-- The destination and payload_length are taken when the payload's first byte is there and must
-- be held until its last (tlast). The payload must come without gaps once its first byte is
-- taken, as ethernet_mac_tx needs. The 42 header bytes go first: IPv4 without options, DF set,
-- TTL 64, the identification counting up, the header checksum computed; the UDP checksum is 0
-- (no checksum, allowed in IPv4). ethernet_mac_tx pads short frames to 60 bytes. The header
-- checksum takes three clocks while the header goes out - it is needed at byte 24.
--
-- addresses with byte 0 (first on the wire) in bits 7:0, ports as numbers; sent: a clock pulse.
entity udp_sender is
    port(
        clock               : in std_logic;

        source_address      : in std_logic_vector(47 downto 0);   -- quasi static
        source_ip           : in std_logic_vector(31 downto 0);
        source_port         : in std_logic_vector(15 downto 0);
        destination_address : in std_logic_vector(47 downto 0);   -- held with the payload
        destination_ip      : in std_logic_vector(31 downto 0);
        destination_port    : in std_logic_vector(15 downto 0);
        payload_length      : in natural range 1 to 1472;

        s_tvalid            : in std_logic;
        s_tready            : out std_logic;
        s_tdata             : in std_logic_vector(7 downto 0);
        s_tlast             : in std_logic;

        m_tvalid            : out std_logic;
        m_tready            : in std_logic;
        m_tdata             : out std_logic_vector(7 downto 0);
        m_tlast             : out std_logic;

        sent                : out boolean
    );
end entity udp_sender;

architecture rtl of udp_sender is

    constant header_length : natural := 42;
    type byte_array is array (natural range <>) of byte;
    subtype header_array is byte_array(0 to header_length-1);

    type states is (idle, header_out, payload_out);
    signal state          : states := idle;
    signal header         : header_array := (others => (others => '0'));
    signal index          : natural range 0 to header_length-1 := 0;
    signal identification : unsigned(15 downto 0) := (others => '0');
    type pair_sums is array (0 to 4) of unsigned(16 downto 0);
    signal pairs          : pair_sums := (others => (others => '0'));
    signal total          : unsigned(19 downto 0) := (others => '0');
    signal checksum_step  : natural range 0 to 3 := 3;

    function address_byte(address : std_logic_vector; i : natural) return byte is
        variable a : std_logic_vector(address'length-1 downto 0) := address;
    begin
        return a(8*i+7 downto 8*i);
    end function;

    function fold(sum : unsigned) return unsigned is
        variable s : unsigned(19 downto 0) := resize(sum, 20);
    begin
        s := resize(s(15 downto 0), 20) + resize(s(19 downto 16), 20);
        s := resize(s(15 downto 0), 20) + resize(s(19 downto 16), 20);
        return s(15 downto 0);
    end function;

    function make_header(
        source_address, destination_address : std_logic_vector(47 downto 0);
        source_ip, destination_ip           : std_logic_vector(31 downto 0);
        source_port, destination_port       : std_logic_vector(15 downto 0);
        payload_length                      : natural;
        identification                      : unsigned(15 downto 0))
    return header_array is
        variable h   : header_array := (others => x"00");
        variable ip_length, udp_length : std_logic_vector(15 downto 0);
    begin
        ip_length  := std_logic_vector(to_unsigned(28 + payload_length, 16));
        udp_length := std_logic_vector(to_unsigned(8 + payload_length, 16));
        for i in 0 to 5 loop
            h(i)   := address_byte(destination_address, i);
            h(6+i) := address_byte(source_address, i);
        end loop;
        h(12) := x"08";  h(13) := x"00";                         -- IPv4
        h(14) := x"45";                                          -- version 4, no options
        h(16) := ip_length(15 downto 8);  h(17) := ip_length(7 downto 0);
        h(18) := std_logic_vector(identification(15 downto 8));
        h(19) := std_logic_vector(identification(7 downto 0));
        h(20) := x"40";                                          -- don't fragment
        h(22) := x"40";                                          -- TTL 64
        h(23) := x"11";                                          -- UDP
        for i in 0 to 3 loop
            h(26+i) := address_byte(source_ip, i);
            h(30+i) := address_byte(destination_ip, i);
        end loop;
        -- bytes 24..25, the header checksum: filled in while the header goes out
        h(34) := source_port(15 downto 8);       h(35) := source_port(7 downto 0);
        h(36) := destination_port(15 downto 8);  h(37) := destination_port(7 downto 0);
        h(38) := udp_length(15 downto 8);        h(39) := udp_length(7 downto 0);
        return h;                                                -- UDP checksum 0
    end function;

begin

    m_tvalid <= '1' when state = header_out else s_tvalid when state = payload_out else '0';
    m_tdata  <= header(index) when state = header_out else s_tdata;
    m_tlast  <= s_tlast when state = payload_out else '0';
    s_tready <= m_tready when state = payload_out else '0';

    process(clock)
    begin
        if rising_edge(clock) then
            sent <= false;
            CASE state is
                WHEN idle =>
                    index <= 0;
                    if s_tvalid = '1' then
                        header <= make_header(source_address, destination_address, source_ip, destination_ip,
                                              source_port, destination_port, payload_length, identification);
                        identification <= identification + 1;
                        checksum_step  <= 0;
                        state <= header_out;
                    end if;

                WHEN header_out =>
                    -- the IPv4 header checksum over the words of bytes 14..33, in three clocks
                    CASE checksum_step is
                        WHEN 0 =>
                            for k in 0 to 4 loop
                                pairs(k) <= resize(unsigned(std_logic_vector'(header(14+4*k) & header(15+4*k))), 17)
                                          + unsigned(std_logic_vector'(header(16+4*k) & header(17+4*k)));
                            end loop;
                            checksum_step <= 1;
                        WHEN 1 =>
                            total <= resize(pairs(0), 20) + pairs(1) + pairs(2) + pairs(3) + pairs(4);
                            checksum_step <= 2;
                        WHEN 2 =>
                            header(24) <= not std_logic_vector(fold(total)(15 downto 8));
                            header(25) <= not std_logic_vector(fold(total)(7 downto 0));
                            checksum_step <= 3;
                        WHEN others =>
                            null;
                    end CASE;
                    if m_tready = '1' then
                        if index = header_length-1 then
                            state <= payload_out;
                        else
                            index <= index + 1;
                        end if;
                    end if;

                WHEN payload_out =>
                    if s_tvalid = '1' and m_tready = '1' and s_tlast = '1' then
                        sent  <= true;
                        state <= idle;
                    end if;
            end CASE;
        end if;
    end process;

end architecture rtl;
