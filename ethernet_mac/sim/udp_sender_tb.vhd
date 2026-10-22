library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

    use work.ethernet_pkg.all;

-- udp_sender and frame_mux: a payload becomes a UDP frame with a right IPv4 header and checksum;
-- two sources at once each get their whole frame through the mux, one after the other. The sink takes frames
-- as ethernet_mac_tx does (tready low through the preamble, then no gaps allowed).
entity udp_sender_tb is
    generic (runner_cfg : string);
end;

architecture vunit_simulation of udp_sender_tb is

    type byte_array is array (natural range <>) of byte;

    signal clock : std_logic := '0';

    -- the payload source
    signal p_tvalid, p_tlast : std_logic := '0';
    signal p_tready : std_logic;
    signal p_tdata  : byte := (others => '0');
    signal payload_length : natural range 1 to 1472 := 1;

    -- udp_sender -> mux a; raw frames -> mux b; mux -> sink
    signal a_tvalid, a_tready, a_tlast : std_logic;
    signal a_tdata : byte;
    signal b_tvalid, b_tlast : std_logic := '0';
    signal b_tready : std_logic;
    signal b_tdata : byte := (others => '0');
    signal m_tvalid, m_tlast : std_logic;
    signal m_tready : std_logic := '0';
    signal m_tdata : byte;
    signal sent : boolean;
    signal sent_count : natural := 0;

    signal out_bytes  : byte_array(0 to 8191);
    signal out_count  : natural := 0;
    type end_array is array (0 to 15) of natural;
    signal out_ends   : end_array := (others => 0);
    signal out_frames : natural := 0;
    signal gap_seen   : boolean := false;
    signal start_b    : boolean := false;

    constant own  : std_logic_vector(47 downto 0) := x"10_00_00_4d_5a_02";   -- 02:5a:4d:00:00:10
    constant pc   : std_logic_vector(47 downto 0) := x"55_44_33_22_11_00";   -- 00:11:22:33:44:55
    constant own_ip : std_logic_vector(31 downto 0) := x"0a_14_a8_c0";       -- 192.168.20.10
    constant pc_ip  : std_logic_vector(31 downto 0) := x"19_14_a8_c0";       -- 192.168.20.25

begin

    clock <= not clock after 4 ns;

    dut : entity work.udp_sender
    port map(
        clock                => clock
        ,source_address      => own
        ,source_ip           => own_ip
        ,source_port         => x"1388"
        ,destination_address => pc
        ,destination_ip      => pc_ip
        ,destination_port    => x"d431"
        ,payload_length      => payload_length
        ,s_tvalid            => p_tvalid
        ,s_tready            => p_tready
        ,s_tdata             => p_tdata
        ,s_tlast             => p_tlast
        ,m_tvalid            => a_tvalid
        ,m_tready            => a_tready
        ,m_tdata             => a_tdata
        ,m_tlast             => a_tlast
        ,sent                => sent
    );

    mux : entity work.frame_mux
    port map(clock, a_tvalid, a_tready, a_tdata, a_tlast, b_tvalid, b_tready, b_tdata, b_tlast,
             m_tvalid, m_tready, m_tdata, m_tlast);

    sink : process(clock)
        variable preamble : natural range 0 to 8 := 0;
        variable in_frame : boolean := false;
    begin
        if rising_edge(clock) then
            if sent then sent_count <= sent_count + 1; end if;
            if m_tready = '1' then
                if m_tvalid = '0' then
                    gap_seen <= true;
                else
                    out_bytes(out_count) <= m_tdata;
                    out_count <= out_count + 1;
                    if m_tlast = '1' then
                        out_ends(out_frames) <= out_count + 1;
                        out_frames <= out_frames + 1;
                        m_tready <= '0';
                        in_frame := false;
                    end if;
                end if;
            elsif m_tvalid = '1' then
                if not in_frame then
                    in_frame := true;
                    preamble := 0;
                elsif preamble = 7 then
                    m_tready <= '1';
                else
                    preamble := preamble + 1;
                end if;
            end if;
        end if;
    end process;

    -- b: a raw 60 byte frame 0x80, 0x81, .. when start_b
    raw_source : process
    begin
        wait until start_b;
        for i in 0 to 59 loop
            b_tvalid <= '1';
            b_tdata  <= std_logic_vector(to_unsigned(16#80# + i, 8));
            b_tlast  <= '1' when i = 59 else '0';
            wait until rising_edge(clock) and b_tready = '1';
        end loop;
        b_tvalid <= '0';
        b_tlast  <= '0';
        wait;
    end process;

    main : process
        function get(f : byte_array; at, n : natural) return std_logic_vector is
            variable v : std_logic_vector(8*n-1 downto 0);
        begin
            for i in 0 to n-1 loop
                v(8*(n-i)-1 downto 8*(n-i-1)) := f(at + i);
            end loop;
            return v;
        end function;

        function csum16(f : byte_array; lo, hi : natural) return unsigned is
            variable acc : unsigned(31 downto 0) := (others => '0');
        begin
            for i in 0 to (hi - lo + 1)/2 - 1 loop
                acc := acc + unsigned(std_logic_vector'(f(lo + 2*i) & f(lo + 2*i + 1)));
            end loop;
            acc := resize(acc(15 downto 0), 32) + acc(31 downto 16);
            acc := resize(acc(15 downto 0), 32) + acc(31 downto 16);
            return acc(15 downto 0);
        end function;

        -- a gapless payload of n bytes, i + seed
        procedure send_payload(n, seed : natural) is
        begin
            payload_length <= n;
            for i in 0 to n-1 loop
                p_tvalid <= '1';
                p_tdata  <= std_logic_vector(to_unsigned((i + seed) mod 256, 8));
                p_tlast  <= '1' when i = n-1 else '0';
                wait until rising_edge(clock) and p_tready = '1';
            end loop;
            p_tvalid <= '0';
            p_tlast  <= '0';
        end procedure;

        variable f : byte_array(0 to 141);
        variable g, h : byte_array(0 to 59);
    begin
        test_runner_setup(runner, runner_cfg);
        wait until rising_edge(clock);

        while test_suite loop
            if run("a_payload_becomes_a_udp_frame") then
                send_payload(100, 7);
                wait until out_frames = 1 for 10 us;
                check_equal(out_frames, 1, "a frame");
                check_equal(out_ends(0), 142, "42 header bytes + 100");
                f := out_bytes(0 to 141);
                check_equal(get(f, 0, 14), std_logic_vector'(x"001122334455_025a4d000010_0800"), "Ethernet header");
                check_equal(get(f, 14, 2), std_logic_vector'(x"4500"), "IPv4, no options");
                check_equal(get(f, 16, 2), std_logic_vector'(x"0080"), "IP total length 128");
                check_equal(get(f, 20, 4), std_logic_vector'(x"40004011"), "DF, TTL 64, UDP");
                check_equal(get(f, 26, 8), std_logic_vector'(x"c0a8140a_c0a81419"), "IP addresses");
                check_equal(csum16(f, 14, 33), unsigned'(x"ffff"), "IP header checksum");
                check_equal(get(f, 34, 8), std_logic_vector'(x"1388_d431_006c_0000"), "UDP header");
                for i in 0 to 99 loop
                    check_equal(f(42 + i), std_logic_vector(to_unsigned((i + 7) mod 256, 8)), "payload " & integer'image(i));
                end loop;
                check(not gap_seen, "no gaps");
                wait for 20 ns;
                check_equal(sent_count, 1, "sent");

            elsif run("the identification counts") then
                send_payload(18, 0);
                send_payload(18, 0);
                wait until out_frames = 2 for 10 us;
                g := out_bytes(0 to 59);
                h := out_bytes(60 to 119);
                check_equal(unsigned(get(h, 18, 2)), unsigned(get(g, 18, 2)) + 1, "identification + 1");

            elsif run("the mux passes both frames whole") then
                start_b <= true;                     -- both sources start together
                send_payload(18, 3);
                wait until out_frames = 2 for 10 us;
                check_equal(out_frames, 2, "two frames");
                check_equal(out_ends(0), 60, "the first whole");
                check_equal(out_ends(1), 120, "the second whole");
                -- one of them is the datagram, the other b's frame, neither mixed with the other
                g := out_bytes(0 to 59);
                h := out_bytes(60 to 119);
                if g(0) = x"80" then
                    g := out_bytes(60 to 119);
                    h := out_bytes(0 to 59);
                end if;
                check_equal(get(g, 12, 2), std_logic_vector'(x"0800"), "the datagram");
                check_equal(g(59), byte'(x"14"), "its last payload byte (17 + 3)");
                for i in 0 to 59 loop
                    check_equal(h(i), std_logic_vector(to_unsigned(16#80# + i, 8)), "b's byte " & integer'image(i));
                end loop;
                check(not gap_seen, "no gaps");
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end vunit_simulation;
