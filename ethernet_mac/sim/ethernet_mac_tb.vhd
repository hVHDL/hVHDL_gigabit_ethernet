LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.ethernet_pkg.all;

-- ethernet_mac as the Zephyr drivers use it, its RGMII transmit pins looped to its receive
-- pins through DDIO models, the registers over APB3 at the TSEMAC offsets, a PHY model on
-- MDIO. Frames go in on the transmit stream and are checked byte for
-- byte as they come out of the receive stream. rx_lo_lags: the receive DDIO model pairs a
-- rising edge nibble with the falling edge before it (true) or after it (false).
entity ethernet_mac_tb is
  generic (runner_cfg : string; rx_lo_lags : boolean := false; loop_delay_ns : real := 2.0);
end;

architecture vunit_simulation of ethernet_mac_tb is

    constant clock_period : time := 8 ns;

    -- registers
    constant COMMAND_CONFIG : natural := 16#008#;
    constant MAC_ADDR_LO    : natural := 16#00c#;
    constant MAC_ADDR_HI    : natural := 16#010#;
    constant FRAMES_TX_OK   : natural := 16#068#;
    constant FRAMES_RX_OK   : natural := 16#06c#;
    constant CRC_ERRORS     : natural := 16#070#;
    constant IF_IN_ERRORS   : natural := 16#088#;
    constant IF_OUT_ERRORS  : natural := 16#08c#;
    constant MDIO_RD_WR_EN  : natural := 16#104#;
    constant MDIO_REG_PHY   : natural := 16#108#;
    constant MDIO_WR_DATA   : natural := 16#10c#;
    constant MDIO_RD_DATA   : natural := 16#110#;
    constant MDIO_STATUS    : natural := 16#114#;
    constant ADDR_MASK_LO   : natural := 16#144#;
    constant ADDR_MASK_HI   : natural := 16#148#;
    constant TX_ENA    : natural := 1;
    constant RX_ENA    : natural := 2;
    constant PROMIS_EN : natural := 16;

    type byte_array is array (natural range <>) of byte;
    constant own_mac   : byte_array(0 to 5) := (x"02", x"00", x"00", x"50", x"53", x"55");
    constant other_mac : byte_array(0 to 5) := (x"02", x"00", x"00", x"50", x"53", x"56");
    constant broadcast : byte_array(0 to 5) := (others => x"FF");

    signal clock    : std_logic := '0';
    signal rx_clock : std_logic := '0';
    signal reset    : std_logic := '0';
    signal rx_reset : std_logic := '0';

    signal paddr   : std_logic_vector(8 downto 0) := (others => '0');
    signal psel, penable, pwrite : std_logic := '0';
    signal pwdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal pready, pslverror : std_logic;
    signal prdata  : std_logic_vector(31 downto 0);

    signal s_tvalid, s_tlast : std_logic := '0';
    signal s_tready : std_logic;
    signal s_tdata  : std_logic_vector(7 downto 0) := (others => '0');
    signal m_tvalid, m_tlast : std_logic;
    signal m_tready : std_logic := '1';
    signal m_tdata  : std_logic_vector(7 downto 0);

    signal rgmii_tx, tx_clock_ddio, rgmii_rx : rgmii_ddio_record := rgmii_idle;
    signal tx_pins, rx_pins : std_logic_vector(4 downto 0) := (others => '0');
    signal rx_hi, rx_lo : std_logic_vector(4 downto 0) := (others => '0');
    signal corrupt : std_logic_vector(4 downto 0) := (others => '0');

    signal mdc, mdio_out, mdio_oe, mdio : std_logic;

    -- what came out of the receive stream
    signal rx_bytes      : byte_array(0 to 32767);
    signal rx_count      : natural := 0;
    type end_array is array (0 to 63) of natural;
    signal rx_frame_ends : end_array := (others => 0);
    signal rx_frames     : natural := 0;

    -- byte i of test frame seed
    function frame_byte(destination : byte_array; seed, i : natural) return byte is
    begin
        if i < 6 then
            return destination(i);
        elsif i < 12 then
            return own_mac(i-6);
        elsif i = 12 then
            return x"88";
        elsif i = 13 then
            return x"B5";
        end if;
        return std_logic_vector(to_unsigned((i*7 + seed*31) mod 256, 8));
    end function;

begin

    clock    <= not clock after clock_period/2;
    -- the PHY's receive clock skew centres the clock in the data eye, a quarter period
    rx_clock <= transport clock after loop_delay_ns * 1 ns + clock_period/4;

    dut : entity work.ethernet_mac
    generic map(g_clocks_per_half_mdc => 4)
    port map(
        clock         => clock
        ,reset        => reset
        ,paddr        => paddr
        ,psel         => psel
        ,penable      => penable
        ,pwrite       => pwrite
        ,pwdata       => pwdata
        ,pready       => pready
        ,prdata       => prdata
        ,pslverror    => pslverror
        ,s_tvalid     => s_tvalid
        ,s_tready     => s_tready
        ,s_tdata      => s_tdata
        ,s_tlast      => s_tlast
        ,rx_clock     => rx_clock
        ,rx_reset     => rx_reset
        ,m_tvalid     => m_tvalid
        ,m_tready     => m_tready
        ,m_tdata      => m_tdata
        ,m_tlast      => m_tlast
        ,rgmii_rx_in  => rgmii_rx
        ,rgmii_tx_out => rgmii_tx
        ,tx_clock_out => tx_clock_ddio
        ,mdc          => mdc
        ,mdio_out     => mdio_out
        ,mdio_oe      => mdio_oe
        ,mdio_in      => mdio
    );

------------------------------------------------------------------------
    -- DDIO output model: both halves registered on the rising edge, hi driven for the first
    -- half of the period and lo for the second
    tx_ddio : process(clock)
        variable lo_hold : std_logic_vector(4 downto 0) := (others => '0');
    begin
        if rising_edge(clock) then
            tx_pins <= rgmii_tx.hi;
            lo_hold := rgmii_tx.lo;
        end if;
        if falling_edge(clock) then
            tx_pins <= lo_hold;
        end if;
    end process;

    -- PHY loopback, corrupt flips pins on the way
    rx_pins <= transport (tx_pins xor corrupt) after loop_delay_ns * 1 ns;

    -- DDIO input model with resync to the rising edge
    rx_ddio : process(rx_clock)
    begin
        if rising_edge(rx_clock) then
            rx_hi <= rx_pins;
            if rx_lo_lags then
                rgmii_rx <= (hi => rx_pins, lo => rx_lo);
            else
                rgmii_rx <= (hi => rx_hi, lo => rx_lo);
            end if;
        end if;
        if falling_edge(rx_clock) then
            rx_lo <= rx_pins;
        end if;
    end process;

    mdio <= mdio_out when mdio_oe = '1' else 'H';

    u_phy : entity work.mdio_phy_model
    generic map(g_phy_address => 0, g_output_delay => 20 ns)
    port map(mdc => mdc, mdio => mdio, link => true);

    sink : process(rx_clock)
    begin
        if rising_edge(rx_clock) then
            if m_tvalid = '1' and m_tready = '1' then
                rx_bytes(rx_count) <= m_tdata;
                rx_count <= rx_count + 1;
                if m_tlast = '1' then
                    rx_frame_ends(rx_frames) <= rx_count + 1;
                    rx_frames <= rx_frames + 1;
                end if;
            end if;
        end if;
    end process;

------------------------------------------------------------------------
    main : process
        variable value : natural;
        variable checked_frames : natural := 0;
        variable checked_bytes  : natural := 0;

        procedure apb_write(address : natural; data : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clock);
            paddr  <= std_logic_vector(to_unsigned(address, 9));
            pwdata <= data;
            pwrite <= '1';
            psel   <= '1';
            wait until rising_edge(clock);
            penable <= '1';
            wait until rising_edge(clock) and pready = '1';
            psel    <= '0';
            penable <= '0';
            pwrite  <= '0';
        end procedure;

        procedure apb_write(address : natural; data : natural) is
        begin
            apb_write(address, std_logic_vector(to_unsigned(data, 32)));
        end procedure;

        procedure apb_read(address : natural; data : out natural) is
        begin
            wait until rising_edge(clock);
            paddr <= std_logic_vector(to_unsigned(address, 9));
            psel  <= '1';
            wait until rising_edge(clock);
            penable <= '1';
            wait until rising_edge(clock) and pready = '1';
            data := to_integer(unsigned(prdata));
            psel    <= '0';
            penable <= '0';
        end procedure;

        procedure check_register(address : natural; expected : natural; message : string) is
            variable v : natural;
        begin
            apb_read(address, v);
            check_equal(v, expected, message);
        end procedure;

        -- the drivers' set up: address, mask, both directions on
        procedure start_mac(command : natural := TX_ENA + RX_ENA) is
        begin
            apb_write(MAC_ADDR_LO, 16#50000002#);
            apb_write(MAC_ADDR_HI, 16#5553#);
            apb_write(ADDR_MASK_LO, x"ffffffff");
            apb_write(ADDR_MASK_HI, 16#ffff#);
            apb_write(COMMAND_CONFIG, command);
        end procedure;

        -- a frame of length bytes (no FCS) into the transmit stream without gaps; with
        -- corrupt_at the line is spoilt at about that byte, with gap_at the stream stops there
        procedure send_frame(destination : byte_array; seed, length : natural;
                             corrupt_at : integer := -1; gap_at : integer := -1) is
        begin
            for i in 0 to length-1 loop
                if i = gap_at then
                    s_tvalid <= '0';
                    wait until rising_edge(clock);
                    wait until rising_edge(clock);
                end if;
                s_tvalid <= '1';
                s_tdata  <= frame_byte(destination, seed, i);
                s_tlast  <= '1' when i = length-1 else '0';
                corrupt  <= "00001" when i = corrupt_at else "00000";
                loop
                    wait until rising_edge(clock);
                    exit when s_tready = '1';
                end loop;
            end loop;
            s_tvalid <= '0';
            s_tlast  <= '0';
            corrupt  <= "00000";
        end procedure;

        -- store and forward: a frame comes out after its last byte, a full one 12 us later
        procedure wait_line_idle is
        begin
            wait for 15 us;
        end procedure;

        -- the next received frame is test frame seed of length bytes, padded to 60 with zeros
        procedure check_frame(destination : byte_array; seed, length : natural) is
            variable start, expected_length : natural;
            variable expected : byte;
        begin
            check(rx_frames > checked_frames, "a frame was received");
            if rx_frames <= checked_frames then
                return;
            end if;
            start := checked_bytes;
            expected_length := maximum(length, 60);
            check_equal(rx_frame_ends(checked_frames) - start, expected_length, "frame length");
            for i in 0 to expected_length-1 loop
                if i < length then
                    expected := frame_byte(destination, seed, i);
                else
                    expected := x"00";
                end if;
                if rx_bytes(start + i) /= expected then
                    check_equal(rx_bytes(start + i), expected, "byte " & integer'image(i) & " of frame " & integer'image(seed));
                    exit;
                end if;
            end loop;
            checked_bytes  := rx_frame_ends(checked_frames);
            checked_frames := checked_frames + 1;
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);

        wait for 100 ns;
        reset <= '1';
        wait until rising_edge(clock);
        reset <= '0';
        wait for 100 ns;

        while test_suite loop
            if run("frames_loop_back_without_their_fcs") then
                start_mac;
                check_register(COMMAND_CONFIG, TX_ENA + RX_ENA, "command config reads back");
                check_register(MAC_ADDR_LO, 16#50000002#, "address low reads back");
                check_register(MAC_ADDR_HI, 16#5553#, "address high reads back");
                send_frame(own_mac, 1, 60);
                send_frame(own_mac, 2, 100);
                send_frame(own_mac, 3, 1514);
                send_frame(own_mac, 4, 61);
                -- back to back: the next frame waits for the gap
                send_frame(own_mac, 5, 64);
                send_frame(own_mac, 6, 64);
                wait_line_idle;
                check_equal(rx_frames, 6, "frames received");
                check_frame(own_mac, 1, 60);
                check_frame(own_mac, 2, 100);
                check_frame(own_mac, 3, 1514);
                check_frame(own_mac, 4, 61);
                check_frame(own_mac, 5, 64);
                check_frame(own_mac, 6, 64);
                check_register(FRAMES_TX_OK, 6, "frames transmitted");
                check_register(FRAMES_RX_OK, 6, "frames received counted");
                check_register(CRC_ERRORS, 0, "no CRC errors");
                check_register(IF_IN_ERRORS, 0, "no receive errors");

            elsif run("short_frames_are_padded_to_60_bytes") then
                start_mac;
                send_frame(own_mac, 1, 14);
                send_frame(own_mac, 2, 42);
                send_frame(own_mac, 3, 59);
                wait_line_idle;
                check_equal(rx_frames, 3, "frames received");
                check_frame(own_mac, 1, 14);
                check_frame(own_mac, 2, 42);
                check_frame(own_mac, 3, 59);

            elsif run("other_addresses_are_dropped_unless_promiscuous") then
                start_mac;
                send_frame(other_mac, 1, 80);
                send_frame(broadcast, 2, 80);
                send_frame(own_mac, 3, 80);
                wait_line_idle;
                check_equal(rx_frames, 2, "broadcast and own received");
                check_frame(broadcast, 2, 80);
                check_frame(own_mac, 3, 80);
                -- the mask's zero bits are not compared
                apb_write(ADDR_MASK_HI, 16#00ff#);
                send_frame(other_mac, 4, 80);
                wait_line_idle;
                check_frame(other_mac, 4, 80);
                apb_write(ADDR_MASK_HI, 16#ffff#);
                apb_write(COMMAND_CONFIG, TX_ENA + RX_ENA + PROMIS_EN);
                send_frame(other_mac, 5, 80);
                wait_line_idle;
                check_frame(other_mac, 5, 80);
                -- receiving off: nothing
                apb_write(COMMAND_CONFIG, TX_ENA);
                send_frame(own_mac, 6, 80);
                wait_line_idle;
                check_equal(rx_frames, 4, "nothing with receiving off");
                check_register(FRAMES_TX_OK, 6, "all transmitted");
                check_register(FRAMES_RX_OK, 4, "received counted");
                check_register(CRC_ERRORS, 0, "no CRC errors");

            elsif run("corrupted_frames_are_dropped") then
                start_mac;
                send_frame(own_mac, 1, 200, corrupt_at => 100);
                send_frame(own_mac, 2, 200);
                send_frame(own_mac, 3, 60, corrupt_at => 4);
                wait_line_idle;
                check_equal(rx_frames, 1, "only the good frame");
                check_frame(own_mac, 2, 200);
                check_register(CRC_ERRORS, 2, "CRC errors counted");
                check_register(FRAMES_RX_OK, 1, "good frame counted");

            elsif run("a_stream_that_runs_dry_spoils_the_frame") then
                start_mac;
                send_frame(own_mac, 1, 300, gap_at => 150);
                send_frame(own_mac, 2, 300);
                wait_line_idle;
                check_equal(rx_frames, 1, "only the whole frame");
                check_frame(own_mac, 2, 300);
                check_register(IF_OUT_ERRORS, 1, "the cut frame counted");
                check_register(FRAMES_TX_OK, 1, "the whole frame sent");
                check_register(CRC_ERRORS, 1, "the cut frame seen as spoilt");

            elsif run("transmitting_off_drops_frames") then
                start_mac(RX_ENA);
                send_frame(own_mac, 1, 100);
                wait_line_idle;
                check_equal(rx_frames, 0, "nothing sent");
                check_register(FRAMES_TX_OK, 0, "nothing counted");
                apb_write(COMMAND_CONFIG, TX_ENA + RX_ENA);
                send_frame(own_mac, 2, 100);
                wait_line_idle;
                check_frame(own_mac, 2, 100);

            elsif run("frames_wait_in_the_fifo_while_the_stream_is_stalled") then
                start_mac;
                m_tready <= '0';
                send_frame(own_mac, 1, 1000);
                send_frame(own_mac, 2, 1000);
                send_frame(own_mac, 3, 1000);
                -- the fourth does not fit into the 4 KB FIFO, the fifth after it does not either
                send_frame(own_mac, 4, 1500);
                send_frame(own_mac, 5, 60);
                wait_line_idle;
                check_equal(rx_frames, 0, "nothing out while stalled");
                check_register(IF_IN_ERRORS, 1, "the frame that did not fit");
                -- a byte at a time, then free
                for i in 0 to 199 loop
                    wait until rising_edge(rx_clock);
                    m_tready <= '1';
                    wait until rising_edge(rx_clock);
                    m_tready <= '0';
                end loop;
                m_tready <= '1';
                wait_line_idle;
                send_frame(own_mac, 6, 500);
                wait_line_idle;
                check_equal(rx_frames, 5, "the frames that fitted and the one after");
                check_frame(own_mac, 1, 1000);
                check_frame(own_mac, 2, 1000);
                check_frame(own_mac, 3, 1000);
                check_frame(own_mac, 5, 60);
                check_frame(own_mac, 6, 500);
                check_register(FRAMES_RX_OK, 5, "received counted");

            elsif run("a_receive_reset_empties_the_fifo") then
                start_mac;
                m_tready <= '0';
                send_frame(own_mac, 1, 300);
                send_frame(own_mac, 2, 300);
                wait_line_idle;
                rx_reset <= '1';
                wait for 100 ns;
                rx_reset <= '0';
                m_tready <= '1';
                wait for 100 ns;
                send_frame(own_mac, 3, 300);
                wait_line_idle;
                check_equal(rx_frames, 1, "only the frame after the reset");
                check_frame(own_mac, 3, 300);

            elsif run("mdio_reads_and_writes_the_phy") then
                apb_write(MDIO_REG_PHY, 16#17# + 0 * 256);
                apb_write(MDIO_WR_DATA, 16#c500#);
                apb_write(MDIO_RD_WR_EN, 2);
                check_register(MDIO_STATUS, 2, "busy at once");
                loop
                    apb_read(MDIO_STATUS, value);
                    exit when value = 0;
                end loop;
                apb_write(MDIO_REG_PHY, 16#02#);
                apb_write(MDIO_RD_WR_EN, 1);
                loop
                    apb_read(MDIO_STATUS, value);
                    exit when value = 0;
                end loop;
                check_register(MDIO_RD_DATA, 16#d565#, "PHY identifier");
                apb_write(MDIO_REG_PHY, 16#17#);
                apb_write(MDIO_RD_WR_EN, 1);
                loop
                    apb_read(MDIO_STATUS, value);
                    exit when value = 0;
                end loop;
                check_register(MDIO_RD_DATA, 16#c500#, "written register");
                -- another PHY address: nobody answers, the bus reads high
                apb_write(MDIO_REG_PHY, 16#02# + 5 * 256);
                apb_write(MDIO_RD_WR_EN, 1);
                loop
                    apb_read(MDIO_STATUS, value);
                    exit when value = 0;
                end loop;
                check_register(MDIO_RD_DATA, 16#ffff#, "no PHY there");

            elsif run("reset_clears_the_registers") then
                start_mac;
                send_frame(own_mac, 1, 60);
                wait_line_idle;
                check_register(FRAMES_RX_OK, 1, "a frame");
                wait until rising_edge(clock);
                reset <= '1';
                wait until rising_edge(clock);
                reset <= '0';
                check_register(COMMAND_CONFIG, 0, "command config");
                check_register(MAC_ADDR_LO, 0, "address");
                check_register(FRAMES_RX_OK, 0, "counter");
                check_register(16#004#, 0, "an address without a register");
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

end vunit_simulation;
