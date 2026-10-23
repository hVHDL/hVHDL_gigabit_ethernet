LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.ethernet_pkg.all;

-- gmii_share between ethernet_mac_tx (fed frames back to back) and another MAC's GMII
-- transmit. Every frame on the line is taken apart and checked: preamble and SFD, the bytes
-- of the frame its first two bytes name (source, sequence number), the sequence numbers in
-- order, at least the interframe gap between frames.
entity gmii_share_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of gmii_share_tb is

    constant clock_period : time := 8 ns;
    constant gap_length   : natural := 12;
    constant mac_source   : natural := 16#4D#;
    constant other_source : natural := 16#6F#;

    signal clock : std_logic := '0';

    signal s_tvalid, s_tlast : std_logic := '0';
    signal s_tready : std_logic;
    signal s_tdata  : std_logic_vector(7 downto 0) := (others => '0');

    signal mac_gmii, other_gmii, line : gmii_record := gmii_idle;
    signal mac_busy, mac_hold : boolean;
    signal frame_passed, frame_dropped : boolean;

    -- stimulus settings
    signal mac_frames, mac_length       : natural := 0;
    signal other_frames, other_length   : natural := 0;
    signal other_gap                    : natural := gap_length;
    signal other_error_at               : integer := -1;   -- this frame gets TX_ER
    signal other_long_at                : integer := -1;   -- this one is 5000 bytes, more than the FIFO
    signal start                        : boolean := false;

    -- what was seen
    signal mac_seen, other_seen, passed, dropped : natural := 0;
    signal other_last_seq : integer := -1;
    signal bad_frames     : natural := 0;
    signal short_gaps     : natural := 0;

    function frame_byte(source, seq, i : natural) return byte is
    begin
        if i = 0 then
            return std_logic_vector(to_unsigned(source, 8));
        elsif i = 1 then
            return std_logic_vector(to_unsigned(seq mod 256, 8));
        end if;
        return std_logic_vector(to_unsigned((i*13 + seq*7 + source) mod 256, 8));
    end function;

begin

    clock <= not clock after clock_period/2;

    u_tx : entity work.ethernet_mac_tx
    port map(
        clock        => clock
        ,enable      => true
        ,hold        => mac_hold
        ,busy        => mac_busy
        ,s_tvalid    => s_tvalid
        ,s_tready    => s_tready
        ,s_tdata     => s_tdata
        ,s_tlast     => s_tlast
        ,gmii_out    => mac_gmii
        ,frame_sent  => open
        ,frame_error => open
    );

    dut : entity work.gmii_share
    generic map(g_fifo_depth => 4096)
    port map(
        clock          => clock
        ,mac_gmii_in   => mac_gmii
        ,mac_busy      => mac_busy
        ,mac_hold      => mac_hold
        ,other_gmii_in => other_gmii
        ,gmii_out      => line
        ,frame_passed  => frame_passed
        ,frame_dropped => frame_dropped
    );

------------------------------------------------------------------------
    -- ethernet_mac_tx's stream: frames without gaps, one after another
    mac_source_p : process
    begin
        wait until start;
        for f in 0 to mac_frames-1 loop
            for i in 0 to mac_length-1 loop
                s_tvalid <= '1';
                s_tdata  <= frame_byte(mac_source, f, i);
                s_tlast  <= '1' when i = mac_length-1 else '0';
                wait until rising_edge(clock) and s_tready = '1';
            end loop;
        end loop;
        s_tvalid <= '0';
        s_tlast  <= '0';
        wait;
    end process;

    -- the other MAC: preamble, SFD, the frame (its last four bytes stand for the FCS), a gap
    other_source_p : process
        variable length : natural;
        procedure put(value : byte; error : boolean := false) is
        begin
            other_gmii <= (data => value, is_valid => true, is_error => error);
            wait until rising_edge(clock);
        end procedure;
    begin
        wait until start;
        wait until rising_edge(clock);
        for f in 0 to other_frames-1 loop
            for i in 0 to 6 loop
                put(preamble_byte);
            end loop;
            put(start_of_frame_byte);
            length := other_length;
            if f = other_long_at then
                length := 5000;
            end if;
            for i in 0 to length-1 loop
                put(frame_byte(other_source, f, i), f = other_error_at and i = 20);
            end loop;
            other_gmii <= gmii_idle;
            for i in 1 to other_gap loop
                wait until rising_edge(clock);
            end loop;
        end loop;
        wait;
    end process;

------------------------------------------------------------------------
    monitor : process(clock)
        type byte_array is array (0 to 2047) of byte;
        variable frame    : byte_array;
        variable length   : natural := 0;
        variable idle_for : natural := 1000;
        variable ok       : boolean;
        variable source, seq : natural;
    begin
        if rising_edge(clock) then
            if frame_passed then passed <= passed + 1; end if;
            if frame_dropped then dropped <= dropped + 1; end if;

            if line.is_valid then
                if length = 0 and idle_for < gap_length then
                    short_gaps <= short_gaps + 1;
                end if;
                if length <= 2047 then
                    frame(length) := line.data;
                end if;
                length := length + 1;
                if line.is_error then
                    bad_frames <= bad_frames + 1;
                end if;
                idle_for := 0;
            else
                if length > 0 then
                    ok := length > 10;
                    for i in 0 to 6 loop
                        ok := ok and frame(i) = preamble_byte;
                    end loop;
                    ok := ok and frame(7) = start_of_frame_byte;
                    if ok then
                        source := to_integer(unsigned(frame(8)));
                        seq    := to_integer(unsigned(frame(9)));
                        if source = mac_source then
                            -- the payload, then padding and the FCS of ethernet_mac_tx
                            ok := length = 8 + maximum(mac_length, 60) + 4 and seq = mac_seen mod 256;
                            for i in 2 to mac_length-1 loop
                                ok := ok and frame(8+i) = frame_byte(mac_source, seq, i);
                            end loop;
                            mac_seen <= mac_seen + 1;
                        elsif source = other_source then
                            ok := length = 8 + other_length and seq > other_last_seq;
                            for i in 2 to other_length-1 loop
                                ok := ok and frame(8+i) = frame_byte(other_source, seq, i);
                            end loop;
                            other_last_seq <= seq;
                            other_seen <= other_seen + 1;
                        else
                            ok := false;
                        end if;
                    end if;
                    if not ok then
                        bad_frames <= bad_frames + 1;
                    end if;
                end if;
                length := 0;
                if idle_for < 1000 then
                    idle_for := idle_for + 1;
                end if;
            end if;
        end if;
    end process;

------------------------------------------------------------------------
    main : process
        procedure run_until_quiet is
            variable quiet : natural := 0;
        begin
            start <= true;
            while quiet < 3000 loop
                wait until rising_edge(clock);
                if line.is_valid or other_gmii.is_valid or s_tvalid = '1' then
                    quiet := 0;
                else
                    quiet := quiet + 1;
                end if;
            end loop;
            info("line: " & integer'image(mac_seen) & " ethernet_mac frames, "
                & integer'image(other_seen) & " from the other MAC; passed " & integer'image(passed)
                & ", dropped " & integer'image(dropped));
            check_equal(bad_frames, 0, "frames spoilt on the line");
            check_equal(short_gaps, 0, "gaps shorter than the interframe gap");
            check_equal(mac_seen, mac_frames, "ethernet_mac frames on the line");
            check_equal(other_seen, passed, "the other MAC's frames on the line against frame_passed");
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("frames from both at once all go out") then
                -- ethernet_mac streaming back to back, the other MAC at a third of the line
                mac_frames   <= 30;
                mac_length   <= 1000;
                other_frames <= 15;
                other_length <= 600;
                other_gap    <= 1200;
                run_until_quiet;
                check_equal(other_seen, other_frames, "the other MAC's frames on the line");
                check_equal(dropped, 0, "frames dropped");

            elsif run("short frames back to back from both") then
                mac_frames   <= 40;
                mac_length   <= 46;
                other_frames <= 40;
                other_length <= 64;
                other_gap    <= gap_length;
                run_until_quiet;
                check_equal(other_seen, other_frames, "the other MAC's frames on the line");

            elsif run("the other MAC alone at the line rate") then
                mac_frames   <= 0;
                other_frames <= 50;
                other_length <= 1518;
                other_gap    <= gap_length;
                run_until_quiet;
                check_equal(other_seen, other_frames, "the other MAC's frames on the line");
                check_equal(dropped, 0, "frames dropped");

            elsif run("a frame with TX_ER is dropped") then
                mac_frames     <= 5;
                mac_length     <= 200;
                other_frames   <= 5;
                other_length   <= 300;
                other_gap      <= 200;
                other_error_at <= 2;
                run_until_quiet;
                check_equal(dropped, 1, "frames dropped");
                check_equal(other_seen, 4, "the other MAC's frames on the line");

            elsif run("both at the line rate: the other MAC first, nothing dropped") then
                -- ethernet_mac waits while the FIFO has frames; it is never too full
                mac_frames   <= 40;
                mac_length   <= 1400;
                other_frames <= 40;
                other_length <= 1400;
                other_gap    <= gap_length;
                run_until_quiet;
                check_equal(other_seen, other_frames, "the other MAC's frames on the line");
                check_equal(dropped, 0, "frames dropped");

            elsif run("a frame longer than the FIFO is dropped whole") then
                mac_frames    <= 5;
                mac_length    <= 1400;
                other_frames  <= 4;
                other_length  <= 1000;
                other_gap     <= gap_length;
                other_long_at <= 1;
                run_until_quiet;
                check_equal(dropped, 1, "frames dropped");
                check_equal(other_seen, 3, "the other MAC's frames on the line");
            end if;
        end loop;

        test_runner_cleanup(runner);
        wait;
    end process;

end vunit_simulation;
