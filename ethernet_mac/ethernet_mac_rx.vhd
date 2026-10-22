library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;
    use work.dual_port_ram_pkg.all;

-- The receive side of ethernet_mac, all in the receive clock: GMII bytes from rgmii_rx (the
-- frame from the destination address on) into a store and forward FIFO, out as an 8 bit AXI
-- stream with tlast on the frame's last byte, the FCS stripped.
--
-- A frame is written into the FIFO while it comes and kept (committed) at its end when
--   its CRC is good and no byte had RX_ER,
--   it is 64..g_max_length bytes with the FCS,
--   it fitted into the FIFO,
--   receiving is enabled, and its destination is the own address (the bits of address_mask
--   compared), broadcast, or anything with promiscuous;
-- else the FIFO's write pointer goes back to the frame's start. The FCS never reaches the
-- FIFO: a byte is written four bytes after it comes, and the last one written is written
-- again at the frame's end with its tlast. The stream gives a committed frame a byte a clock
-- while tready is high.
--
-- counters, each a clock pulse: frame_received (committed), crc_error (CRC or RX_ER),
-- frame_error (length, the FIFO full or a clear while it came). Frames for other addresses and frames while receiving
-- is disabled are dropped without one.
entity ethernet_mac_rx is
    generic(
        g_fifo_depth : positive := 4096;   -- bytes, a power of two, more than a frame
        g_max_length : positive := 1522    -- bytes with the FCS: 1518 and a VLAN tag
    );
    port(
        clock          : in std_logic;
        clear          : in boolean := false;   -- empties the FIFO, drops the frame coming
        gmii_in        : in gmii_record;
        frame_is_ended : in boolean;

        -- configuration, quasi static: synchronised into this clock by the caller
        enable         : in boolean;
        promiscuous    : in boolean;
        own_address    : in std_logic_vector(47 downto 0);  -- byte 0 (first on the wire) in bits 7:0
        address_mask   : in std_logic_vector(47 downto 0);

        m_tvalid       : out std_logic;
        m_tready       : in std_logic;
        m_tdata        : out std_logic_vector(7 downto 0);
        m_tlast        : out std_logic;

        frame_received : out boolean;
        crc_error      : out boolean;
        frame_error    : out boolean
    );
end entity ethernet_mac_rx;

architecture rtl of ethernet_mac_rx is

    function address_bits return natural is
        variable bits : natural := 0;
    begin
        while 2**bits < g_fifo_depth loop
            bits := bits + 1;
        end loop;
        return bits;
    end function;

    constant ram_subtype : dpram_ref_record := create_ref_subtypes(datawidth => 9, addresswidth => address_bits);
    constant ram_init    : ram_array(0 to g_fifo_depth-1)(8 downto 0) := (others => (others => '0'));
    signal ram_write_in, ram_read_in : ram_subtype.ram_in'subtype;
    signal ram_read_out : ram_subtype.ram_out'subtype;

    -- one bit more than the address: full and empty told apart
    subtype pointer is unsigned(address_bits downto 0);

    -- writer
    type byte_array is array (natural range <>) of byte;
    signal delay         : byte_array(0 to 3) := (others => (others => '0'));
    signal index         : natural range 0 to g_max_length+1 := 0;
    signal crc           : std_logic_vector(31 downto 0) := crc32_init;
    signal had_error     : boolean := false;
    signal overflowed    : boolean := false;
    signal is_own        : boolean := true;
    signal is_broadcast  : boolean := true;
    signal write_pointer : pointer := (others => '0');
    signal frame_start   : pointer := (others => '0');   -- the committed end, for the reader
    signal last_written  : byte := (others => '0');

    -- reader: a three entry queue in front of the stream, as a read's data comes two clocks
    -- after the request (it is registered here, then in the RAM)
    type queue_entry is record
        data : byte;
        last : std_logic;
    end record;
    type queue_array is array (0 to 2) of queue_entry;
    signal read_pointer : pointer := (others => '0');
    signal queue        : queue_array := (others => ((others => '0'), '0'));
    signal queued       : natural range 0 to 3 := 0;
    signal in_flight    : std_logic_vector(1 downto 0) := (others => '0');  -- bit 1 lands now

begin

    m_tvalid <= '1' when queued > 0 else '0';
    m_tdata  <= queue(0).data;
    m_tlast  <= queue(0).last;

    u_ram : entity work.simple_dual_port_ram
    generic map(g_dpram_subtype => ram_subtype, g_ram_init_values => ram_init, g_output_register => false)
    port map(clock => clock, write_in => ram_write_in, read_in => ram_read_in, read_out => ram_read_out);

------------------------------------------------------------------------
    writer : process(clock)
        variable used : pointer;
        variable byte_number : natural range 0 to 5;

        procedure write_fifo(address : pointer; data : byte; last : std_logic) is
        begin
            write_data_to_ram(ram_write_in, to_integer(address(address_bits-1 downto 0)), last & data);
        end procedure;
    begin
        if rising_edge(clock) then
            init_ram(ram_write_in);
            frame_received <= false;
            crc_error      <= false;
            frame_error    <= false;

            used := write_pointer - read_pointer;

            if gmii_in.is_valid then
                delay <= delay(1 to 3) & gmii_in.data;
                crc   <= next_crc32(crc, gmii_in.data);
                if gmii_in.is_error then
                    had_error <= true;
                end if;
                if index <= g_max_length then
                    index <= index + 1;
                end if;

                if index < 6 then
                    byte_number := index;
                    if ((gmii_in.data xor own_address(8*byte_number+7 downto 8*byte_number))
                        and address_mask(8*byte_number+7 downto 8*byte_number)) /= x"00" then
                        is_own <= false;
                    end if;
                    if gmii_in.data /= x"FF" then
                        is_broadcast <= false;
                    end if;
                end if;

                -- the byte four before this one, so the FCS stays out
                if index >= 4 and index < g_max_length and not overflowed then
                    if used < g_fifo_depth then
                        write_fifo(write_pointer, delay(0), '0');
                        write_pointer <= write_pointer + 1;
                        last_written  <= delay(0);
                    else
                        overflowed <= true;
                    end if;
                end if;
            end if;

            if frame_is_ended and index > 0 then
                if crc /= crc32_residue or had_error then
                    crc_error     <= true;
                    write_pointer <= frame_start;
                elsif index < 64 or index > g_max_length or overflowed then
                    frame_error   <= true;
                    write_pointer <= frame_start;
                elsif not enable or not (is_own or is_broadcast or promiscuous) then
                    write_pointer <= frame_start;
                else
                    -- the last byte again, now with its tlast
                    write_fifo(write_pointer - 1, last_written, '1');
                    frame_start    <= write_pointer;
                    frame_received <= true;
                end if;
                index        <= 0;
                crc          <= crc32_init;
                had_error    <= false;
                overflowed   <= false;
                is_own       <= true;
                is_broadcast <= true;
            end if;

            if clear then
                init_ram(ram_write_in);
                write_pointer <= (others => '0');
                frame_start   <= (others => '0');
                -- the frame coming is not written, as if it had overflowed
                overflowed    <= index > 0 or gmii_in.is_valid;
            end if;
        end if;
    end process;

------------------------------------------------------------------------
    reader : process(clock)
        variable pop   : boolean;
        variable count : natural range 0 to 4;
        variable word  : std_logic_vector(8 downto 0);
        variable issue : boolean;
    begin
        if rising_edge(clock) then
            init_ram(ram_read_in);
            pop := queued > 0 and m_tready = '1';

            count := queued;
            if pop then
                queue(0 to 1) <= queue(1 to 2);
                count := count - 1;
            end if;
            if in_flight(1) = '1' then
                word := get_ram_data(ram_read_out);
                queue(count) <= (word(7 downto 0), word(8));
                count := count + 1;
            end if;
            queued <= count;

            -- room for this read and the one still on its way
            issue := read_pointer /= frame_start and count + to_integer(unsigned(in_flight(0 downto 0))) <= 2;
            in_flight <= in_flight(0) & '0';
            if issue then
                request_data_from_ram(ram_read_in, to_integer(read_pointer(address_bits-1 downto 0)));
                read_pointer <= read_pointer + 1;
                in_flight(0) <= '1';
            end if;

            if clear then
                read_pointer <= (others => '0');
                queued       <= 0;
                in_flight    <= (others => '0');
            end if;
        end if;
    end process;

end architecture rtl;
