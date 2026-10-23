library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;
    use work.dual_port_ram_pkg.all;

-- The transmit side of a port shared by ethernet_mac and another MAC, all in the transmit
-- clock: frames from the other MAC's GMII transmit (whole, the preamble and the FCS with them)
-- and from ethernet_mac_tx onto one GMII.
--
-- GMII has no back-pressure, so the other MAC's frames go through a FIFO: a frame is written
-- while it comes and kept at its end, or dropped whole if it had TX_ER or did not fit. A kept
-- frame waits until ethernet_mac_tx is idle - hold keeps it from starting one - then goes out
-- gaplessly, followed by the interframe gap. The FIFO has priority: hold is let go only when
-- it is empty. ethernet_mac_tx can wait, the other MAC cannot, and as it sends no faster than
-- the line the FIFO never holds more than what came during one of ethernet_mac_tx's frames.
--
-- counters, each a clock pulse: frame_passed (one from the FIFO sent), frame_dropped.
entity gmii_share is
    generic(
        g_fifo_depth : positive := 4096   -- bytes, a power of two, more than a frame
    );
    port(
        clock         : in std_logic;

        -- ethernet_mac_tx
        mac_gmii_in   : in gmii_record;
        mac_busy      : in boolean;
        mac_hold      : out boolean;

        -- the other MAC's GMII transmit, on clock
        other_gmii_in : in gmii_record;

        gmii_out      : out gmii_record;

        frame_passed  : out boolean;
        frame_dropped : out boolean
    );
end entity gmii_share;

architecture rtl of gmii_share is

    function address_bits return natural is
        variable bits : natural := 0;
    begin
        while 2**bits < g_fifo_depth loop
            bits := bits + 1;
        end loop;
        return bits;
    end function;

    constant gap_length : natural := 12;

    constant ram_subtype : dpram_ref_record := create_ref_subtypes(datawidth => 9, addresswidth => address_bits);
    constant ram_init    : ram_array(0 to g_fifo_depth-1)(8 downto 0) := (others => (others => '0'));
    signal ram_write_in, ram_read_in : ram_subtype.ram_in'subtype;
    signal ram_read_out : ram_subtype.ram_out'subtype;

    subtype pointer is unsigned(address_bits downto 0);

    -- writer
    signal in_frame      : boolean := false;
    signal had_error     : boolean := false;
    signal overflowed    : boolean := false;
    signal write_pointer : pointer := (others => '0');
    signal frame_start   : pointer := (others => '0');   -- the committed end, for the reader
    signal last_written  : byte := (others => '0');

    -- reader: a queue in front of the line, as in ethernet_mac_rx
    type queue_entry is record
        data : byte;
        last : std_logic;
    end record;
    type queue_array is array (0 to 2) of queue_entry;
    signal read_pointer : pointer := (others => '0');
    signal queue        : queue_array := (others => ((others => '0'), '0'));
    signal queued       : natural range 0 to 3 := 0;
    signal in_flight    : std_logic_vector(1 downto 0) := (others => '0');

    -- the line
    type states is (idle, waiting, sending, gap);
    signal state : states := idle;
    signal hold  : boolean := false;
    signal count : natural range 0 to gap_length := 0;
    signal pop   : boolean;

begin

    mac_hold <= hold;

    u_ram : entity work.simple_dual_port_ram
    generic map(g_dpram_subtype => ram_subtype, g_ram_init_values => ram_init, g_output_register => false)
    port map(clock => clock, write_in => ram_write_in, read_in => ram_read_in, read_out => ram_read_out);

------------------------------------------------------------------------
    writer : process(clock)
        variable used : pointer;

        procedure write_fifo(address : pointer; data : byte; last : std_logic) is
        begin
            write_data_to_ram(ram_write_in, to_integer(address(address_bits-1 downto 0)), last & data);
        end procedure;
    begin
        if rising_edge(clock) then
            init_ram(ram_write_in);
            frame_dropped <= false;

            used := write_pointer - read_pointer;

            if other_gmii_in.is_valid then
                in_frame <= true;
                if other_gmii_in.is_error then
                    had_error <= true;
                end if;
                if not overflowed then
                    if used < g_fifo_depth then
                        write_fifo(write_pointer, other_gmii_in.data, '0');
                        write_pointer <= write_pointer + 1;
                        last_written  <= other_gmii_in.data;
                    else
                        overflowed <= true;
                    end if;
                end if;
            elsif in_frame then
                if had_error or overflowed then
                    write_pointer <= frame_start;
                    frame_dropped <= true;
                else
                    -- the last byte again, now with its tlast
                    write_fifo(write_pointer - 1, last_written, '1');
                    frame_start <= write_pointer;
                end if;
                in_frame   <= false;
                had_error  <= false;
                overflowed <= false;
            end if;
        end if;
    end process;

------------------------------------------------------------------------
    reader : process(clock)
        variable n     : natural range 0 to 4;
        variable word  : std_logic_vector(8 downto 0);
        variable issue : boolean;
    begin
        if rising_edge(clock) then
            init_ram(ram_read_in);

            n := queued;
            if pop then
                queue(0 to 1) <= queue(1 to 2);
                n := n - 1;
            end if;
            if in_flight(1) = '1' then
                word := get_ram_data(ram_read_out);
                queue(n) <= (word(7 downto 0), word(8));
                n := n + 1;
            end if;
            queued <= n;

            issue := read_pointer /= frame_start and n + to_integer(unsigned(in_flight(0 downto 0))) <= 2;
            in_flight <= in_flight(0) & '0';
            if issue then
                request_data_from_ram(ram_read_in, to_integer(read_pointer(address_bits-1 downto 0)));
                read_pointer <= read_pointer + 1;
                in_flight(0) <= '1';
            end if;
        end if;
    end process;

------------------------------------------------------------------------
    pop <= state = sending and queued > 0;

    line : process(clock)
    begin
        if rising_edge(clock) then
            frame_passed <= false;
            gmii_out     <= mac_gmii_in;

            CASE state is
                WHEN idle =>
                    hold <= false;
                    if queued > 0 then
                        hold  <= true;
                        state <= waiting;
                    end if;

                -- hold has been high for a clock: ethernet_mac_tx starts nothing new from here on
                WHEN waiting =>
                    if not mac_busy then
                        state <= sending;
                    end if;

                WHEN sending =>
                    if queued > 0 then
                        gmii_out <= (data => queue(0).data, is_valid => true, is_error => false);
                        if queue(0).last = '1' then
                            frame_passed <= true;
                            count <= 0;
                            state <= gap;
                        end if;
                    else
                        -- the queue ran dry: cannot happen with a committed frame, spoil it
                        gmii_out <= (data => x"00", is_valid => true, is_error => true);
                    end if;

                WHEN gap =>
                    if count < gap_length-1 then
                        count <= count + 1;
                    elsif queued > 0 then
                        state <= sending;
                    else
                        hold  <= false;
                        state <= idle;
                    end if;
            end CASE;
        end if;
    end process;

end architecture rtl;
