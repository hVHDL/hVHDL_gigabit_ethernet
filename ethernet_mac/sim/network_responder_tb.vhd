library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

    use work.ethernet_pkg.all;

-- network_responder between two streams in unrelated clocks: requests into s_t* (rx_clock), the
-- replies out of m_t* (clock) into a sink that takes them as ethernet_mac_tx does - tready low
-- through the preamble, then high and no gaps allowed until tlast. The testbench builds ARP, ICMP
-- and UDP requests with their checksums and checks the replies' fields and checksums itself.
entity network_responder_tb is
    generic (runner_cfg : string);
end;

architecture vunit_simulation of network_responder_tb is

    type byte_array is array (natural range <>) of byte;

    -- own address and IP with byte 0 in bits 7:0, as the ports take them
    constant own_mac  : byte_array(0 to 5) := (x"02", x"5a", x"4d", x"00", x"00", x"10");
    constant own_ip   : byte_array(0 to 3) := (x"c0", x"a8", x"14", x"0a");   -- 192.168.20.10
    constant pc_mac   : byte_array(0 to 5) := (x"00", x"11", x"22", x"33", x"44", x"55");
    constant pc_ip    : byte_array(0 to 3) := (x"c0", x"a8", x"14", x"19");   -- 192.168.20.25
    constant other_ip : byte_array(0 to 3) := (x"c0", x"a8", x"14", x"63");
    constant broadcast : byte_array(0 to 5) := (others => x"ff");

    function little_endian(bytes : byte_array) return std_logic_vector is
        variable v : std_logic_vector(8*bytes'length-1 downto 0);
    begin
        for i in 0 to bytes'length-1 loop
            v(8*i+7 downto 8*i) := bytes(bytes'low+i);
        end loop;
        return v;
    end function;

    signal rx_clock : std_logic := '0';
    signal clock    : std_logic := '0';

    signal s_tvalid, s_tlast : std_logic := '0';
    signal s_tready : std_logic;
    signal s_tdata  : byte := (others => '0');
    signal m_tvalid, m_tlast : std_logic;
    signal m_tready : std_logic := '0';
    signal m_tdata  : byte;

    signal arp_replied, icmp_replied, udp_replied, raw_echoed, user_received, ignored : boolean;
    signal user_tvalid, user_tlast : std_logic;
    signal user_tdata : byte;
    signal user_length : natural range 0 to 2047;
    signal user_source_address : std_logic_vector(47 downto 0);
    signal user_source_ip : std_logic_vector(31 downto 0);
    signal user_source_port : std_logic_vector(15 downto 0);
    signal user_bytes : byte_array(0 to 2047);
    signal user_count, user_frames, user_seen_length : natural := 0;
    signal user_seen_address : std_logic_vector(47 downto 0) := (others => '0');
    signal user_seen_ip : std_logic_vector(31 downto 0) := (others => '0');
    signal user_seen_port : std_logic_vector(15 downto 0) := (others => '0');
    signal arp_count, icmp_count, udp_count, raw_count, ignored_count : natural := 0;

    -- what came out
    signal out_bytes  : byte_array(0 to 8191);
    signal out_count  : natural := 0;
    type end_array is array (0 to 15) of natural;
    signal out_ends   : end_array := (others => 0);
    signal out_frames : natural := 0;
    signal gap_seen   : boolean := false;

begin

    rx_clock <= not rx_clock after 4 ns;
    clock    <= not clock after 4.002 ns;

    dut : entity work.network_responder
    port map(
        rx_clock       => rx_clock
        ,s_tvalid      => s_tvalid
        ,s_tready      => s_tready
        ,s_tdata       => s_tdata
        ,s_tlast       => s_tlast
        ,clock         => clock
        ,m_tvalid      => m_tvalid
        ,m_tready      => m_tready
        ,m_tdata       => m_tdata
        ,m_tlast       => m_tlast
        ,own_address   => little_endian(own_mac)
        ,own_ip        => little_endian(own_ip)
        ,udp_echo_port => x"0007"
        ,udp_user_port => x"1388"   -- 5000
        ,user_tvalid   => user_tvalid
        ,user_tready   => '1'
        ,user_tdata    => user_tdata
        ,user_tlast    => user_tlast
        ,user_length   => user_length
        ,user_source_address => user_source_address
        ,user_source_ip      => user_source_ip
        ,user_source_port    => user_source_port
        ,arp_replied   => arp_replied
        ,icmp_replied  => icmp_replied
        ,udp_replied   => udp_replied
        ,raw_echoed    => raw_echoed
        ,user_received => user_received
        ,ignored       => ignored
    );

    -- the sink, as ethernet_mac_tx: 8 clocks of preamble, then a byte a clock until tlast
    sink : process(clock)
        variable preamble : natural range 0 to 8 := 0;
        variable in_frame : boolean := false;
    begin
        if rising_edge(clock) then
            if arp_replied  then arp_count  <= arp_count + 1;  end if;
            if icmp_replied then icmp_count <= icmp_count + 1; end if;
            if udp_replied  then udp_count  <= udp_count + 1;  end if;
            if raw_echoed   then raw_count  <= raw_count + 1;  end if;
            if ignored      then ignored_count <= ignored_count + 1; end if;

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

    user_sink : process(clock)
    begin
        if rising_edge(clock) and user_tvalid = '1' then
            user_bytes(user_count) <= user_tdata;
            user_count <= user_count + 1;
            if user_tlast = '1' then
                user_frames       <= user_frames + 1;
                user_seen_length  <= user_length;
                user_seen_address <= user_source_address;
                user_seen_ip      <= user_source_ip;
                user_seen_port    <= user_source_port;
            end if;
        end if;
    end process;

    main : process

        function put(f : byte_array; at : natural; v : byte_array) return byte_array is
            variable r : byte_array(f'range) := f;
        begin
            for i in v'range loop
                r(at + i - v'low) := v(i);
            end loop;
            return r;
        end function;

        function put(f : byte_array; at : natural; v : std_logic_vector) return byte_array is
            variable r : byte_array(f'range) := f;
            constant n : natural := v'length/8;
            variable w : std_logic_vector(v'length-1 downto 0) := v;
        begin
            for i in 0 to n-1 loop
                r(at + i) := w(8*(n-i)-1 downto 8*(n-i-1));
            end loop;
            return r;
        end function;

        function get(f : byte_array; at, n : natural) return std_logic_vector is
            variable v : std_logic_vector(8*n-1 downto 0);
        begin
            for i in 0 to n-1 loop
                v(8*(n-i)-1 downto 8*(n-i-1)) := f(at + i);
            end loop;
            return v;
        end function;

        function bytes_of(b : byte_array) return std_logic_vector is
        begin
            return get(b, b'low, b'length);
        end function;

        -- ones' complement sum of the 16 bit words of f(lo .. hi), folded
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

        function ethernet(destination : byte_array; ethertype : std_logic_vector(15 downto 0); n : natural)
            return byte_array is
            variable f : byte_array(0 to n-1) := (others => x"00");
        begin
            f := put(f, 0, destination);
            f := put(f, 6, pc_mac);
            f := put(f, 12, ethertype);
            return f;
        end function;

        function arp_request(asked : byte_array) return byte_array is
            variable f : byte_array(0 to 59);
        begin
            f := ethernet(broadcast, x"0806", 60);
            f := put(f, 14, std_logic_vector'(x"0001080006040001"));
            f := put(f, 22, pc_mac);
            f := put(f, 28, pc_ip);
            f := put(f, 38, asked);
            return f;
        end function;

        -- Ethernet + IPv4 (no options, checksum in) + payload
        function ipv4(destination : byte_array; ip : byte_array; protocol : byte; payload : byte_array)
            return byte_array is
            variable f : byte_array(0 to 33 + payload'length);
        begin
            f := ethernet(destination, x"0800", f'length);
            f := put(f, 14, std_logic_vector'(x"45"));
            f := put(f, 16, std_logic_vector(to_unsigned(20 + payload'length, 16)));
            f := put(f, 18, std_logic_vector'(x"1234"));
            f := put(f, 20, std_logic_vector'(x"4000"));   -- don't fragment
            f := put(f, 22, std_logic_vector'(x"40"));
            f(23) := protocol;
            f := put(f, 26, pc_ip);
            f := put(f, 30, ip);
            f := put(f, 24, std_logic_vector(not csum16(f, 14, 33)));
            return put(f, 34, payload);
        end function;

        function icmp_echo_request(n : natural) return byte_array is
            variable m : byte_array(0 to 7 + n) := (others => x"00");
        begin
            m := put(m, 0, std_logic_vector'(x"0800"));
            m := put(m, 4, std_logic_vector'(x"beef0001"));
            for i in 0 to n-1 loop
                m(8 + i) := std_logic_vector(to_unsigned((13*i + 5) mod 256, 8));
            end loop;
            return put(m, 2, std_logic_vector(not csum16(m, 0, m'high)));
        end function;

        -- UDP with its checksum over the pseudo header; n even
        function udp_datagram(ip : byte_array; port_number : std_logic_vector(15 downto 0); n : natural)
            return byte_array is
            variable u : byte_array(0 to 7 + n) := (others => x"00");
            variable p : byte_array(0 to 19 + n) := (others => x"00");
        begin
            u := put(u, 0, std_logic_vector'(x"d431"));
            u := put(u, 2, port_number);
            u := put(u, 4, std_logic_vector(to_unsigned(8 + n, 16)));
            for i in 0 to n-1 loop
                u(8 + i) := std_logic_vector(to_unsigned((7*i + 3) mod 256, 8));
            end loop;
            p := put(p, 0, pc_ip);
            p := put(p, 4, ip);
            p := put(p, 8, std_logic_vector'(x"0011"));
            p := put(p, 10, std_logic_vector(to_unsigned(8 + n, 16)));
            p := put(p, 12, u);
            return put(u, 6, std_logic_vector(not csum16(p, 0, p'high)));
        end function;

        procedure send(f : byte_array) is
        begin
            for i in f'range loop
                s_tvalid <= '1';
                s_tdata  <= f(i);
                s_tlast  <= '1' when i = f'high else '0';
                wait until rising_edge(rx_clock) and s_tready = '1';
            end loop;
            s_tvalid <= '0';
            s_tlast  <= '0';
        end procedure;

        impure function reply(n : natural) return byte_array is
            variable first : natural := 0;
        begin
            if n > 0 then
                first := out_ends(n-1);
            end if;
            return out_bytes(first to out_ends(n) - 1);
        end function;

        procedure wait_for_frames(n : natural) is
        begin
            wait until out_frames = n for 20 us;
            check_equal(out_frames, n, "replies");
            wait for 50 ns;   -- the counter pulses come with the last byte, counted a clock later
        end procedure;

        procedure expect_nothing is
        begin
            wait for 10 us;
            check_equal(out_frames, 0, "no reply");
            check_equal(ignored_count, 1, "counted as ignored");
        end procedure;

        variable arp_frame  : byte_array(0 to 59);
        variable ping_frame : byte_array(0 to 73);
        variable udp_frame  : byte_array(0 to 63);
        variable r60        : byte_array(0 to 59);
        variable r74        : byte_array(0 to 73);
        variable r64        : byte_array(0 to 63);

    begin
        test_runner_setup(runner, runner_cfg);
        wait for 200 ns;   -- the configuration crosses to rx_clock

        while test_suite loop
            if run("arp_request_for_own_ip_is_answered") then
                send(arp_request(own_ip));
                wait_for_frames(1);
                r60 := reply(0);
                check_equal(get(r60, 0, 6), bytes_of(pc_mac), "to the requester");
                check_equal(get(r60, 6, 6), bytes_of(own_mac), "from us");
                check_equal(get(r60, 12, 10), std_logic_vector'(x"08060001080006040002"), "an ARP reply");
                check_equal(get(r60, 22, 6), bytes_of(own_mac), "sender MAC");
                check_equal(get(r60, 28, 4), bytes_of(own_ip), "sender IP");
                check_equal(get(r60, 32, 6), bytes_of(pc_mac), "target MAC");
                check_equal(get(r60, 38, 4), bytes_of(pc_ip), "target IP");
                check_equal(arp_count, 1, "arp_replied");
                check(not gap_seen, "no gap in the reply");

            elsif run("arp_request_for_another_ip_is_ignored") then
                send(arp_request(other_ip));
                expect_nothing;

            elsif run("ping_is_answered") then
                ping_frame := ipv4(own_mac, own_ip, x"01", icmp_echo_request(32));
                send(ping_frame);
                wait_for_frames(1);
                r74 := reply(0);
                check_equal(get(r74, 0, 6), bytes_of(pc_mac), "to the sender");
                check_equal(get(r74, 26, 4), bytes_of(own_ip), "IP source");
                check_equal(get(r74, 30, 4), bytes_of(pc_ip), "IP destination");
                check_equal(csum16(r74, 14, 33), unsigned'(x"ffff"), "IP header checksum");
                check_equal(r74(34), byte'(x"00"), "echo reply");
                check_equal(csum16(r74, 34, r74'high), unsigned'(x"ffff"), "ICMP checksum");
                check_equal(get(r74, 38, 36), get(ping_frame, 38, 36), "id, sequence and data kept");
                check_equal(icmp_count, 1, "icmp_replied");
                check(not gap_seen, "no gap in the reply");

            elsif run("udp_to_the_echo_port_is_echoed") then
                udp_frame := ipv4(own_mac, own_ip, x"11", udp_datagram(own_ip, x"0007", 22));
                send(udp_frame);
                wait_for_frames(1);
                r64 := reply(0);
                check_equal(get(r64, 26, 4), bytes_of(own_ip), "IP source");
                check_equal(get(r64, 30, 4), bytes_of(pc_ip), "IP destination");
                check_equal(csum16(r64, 14, 33), unsigned'(x"ffff"), "IP header checksum");
                check_equal(get(r64, 34, 4), std_logic_vector'(x"0007d431"), "the ports swapped");
                check_equal(get(r64, 38, 26), get(udp_frame, 38, 26), "length, checksum and data kept");
                check_equal(udp_count, 1, "udp_replied");

            elsif run("udp_to_another_port_is_ignored") then
                send(ipv4(own_mac, own_ip, x"11", udp_datagram(own_ip, x"1234", 22)));
                expect_nothing;

            elsif run("bad_ip_header_checksum_is_ignored") then
                ping_frame := ipv4(own_mac, own_ip, x"01", icmp_echo_request(32));
                ping_frame(25) := ping_frame(25) xor x"01";
                send(ping_frame);
                expect_nothing;

            elsif run("ip_to_the_broadcast_mac_is_ignored") then
                send(ipv4(broadcast, own_ip, x"01", icmp_echo_request(32)));
                expect_nothing;

            elsif run("raw_frames_are_echoed") then
                send(put(ethernet(own_mac, x"88b5", 60), 14, std_logic_vector'(x"0102030405")));
                wait_for_frames(1);
                r60 := reply(0);
                check_equal(get(r60, 0, 12), bytes_of(pc_mac) & bytes_of(own_mac), "addresses swapped");
                check_equal(get(r60, 12, 7), std_logic_vector'(x"88b50102030405"), "the rest as sent");
                check_equal(raw_count, 1, "raw_echoed");

            elsif run("datagrams_to_the_user_port_are_handed_over") then
                udp_frame := ipv4(own_mac, own_ip, x"11", udp_datagram(own_ip, x"1388", 22));
                send(udp_frame);
                wait until user_frames = 1 for 20 us;
                check_equal(user_frames, 1, "handed over");
                check_equal(user_seen_length, 22, "payload length");
                check_equal(user_count, 22, "payload bytes");
                for i in 0 to 21 loop
                    check_equal(user_bytes(i), udp_frame(42 + i), "payload byte " & integer'image(i));
                end loop;
                check_equal(user_seen_address, little_endian(pc_mac), "sender's address");
                check_equal(user_seen_ip, little_endian(pc_ip), "sender's IP");
                check_equal(user_seen_port, std_logic_vector'(x"d431"), "sender's port");
                check_equal(out_frames, 0, "no reply on m_t*");

            elsif run("a short padded datagram is handed over with its own length") then
                send(ipv4(own_mac, own_ip, x"11", udp_datagram(own_ip, x"1388", 4)) & byte_array'(0 to 9 => x"00"));
                wait until user_frames = 1 for 20 us;
                check_equal(user_frames, 1, "handed over");
                check_equal(user_count, 4, "4 payload bytes, not the padding");

            elsif run("an empty datagram to the user port is ignored") then
                send(ipv4(own_mac, own_ip, x"11", udp_datagram(own_ip, x"1388", 0)) & byte_array'(0 to 17 => x"00"));
                wait for 10 us;
                check_equal(user_frames, 0, "nothing handed over");

            elsif run("back_to_back_requests_are_both_answered") then
                send(arp_request(own_ip));
                send(ipv4(own_mac, own_ip, x"01", icmp_echo_request(32)));
                wait_for_frames(2);
                check_equal(out_ends(0), 60, "the ARP reply first");
                check_equal(out_ends(1) - out_ends(0), 74, "then the echo reply");
                check(not gap_seen, "no gaps");
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

end vunit_simulation;
