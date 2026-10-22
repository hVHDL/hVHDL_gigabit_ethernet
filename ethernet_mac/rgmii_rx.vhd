library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;

-- RGMII DDIO halves to a GMII byte stream.
-- The pairing of the rising and falling edge nibbles after the DDIO resync registers is
-- found from the start of frame delimiter: three pairings are decoded in parallel and the
-- one that shows 0x55 followed by 0xD5 is used for the rest of the frame.
--   0: hi(t) with lo(t), 1: hi(t-1) with lo(t), 2: hi(t) with lo(t-1)
entity rgmii_rx is
    port(
        clock          : in std_logic;
        rgmii_in       : in rgmii_ddio_record;
        gmii_out       : out gmii_record;     -- valid from the first byte after the SFD
        alignment      : out natural range 0 to 3;  -- 3 = no SFD found yet
        frame_is_ended : out boolean
    );
end entity rgmii_rx;

architecture rtl of rgmii_rx is

    type byte_array is array (0 to 2) of byte;
    type dv_array is array (0 to 2) of std_logic;

    signal hi_d, lo_d   : std_logic_vector(4 downto 0) := (others => '0');
    signal candidate    : byte_array := (others => (others => '0'));
    signal candidate_dv : dv_array := (others => '0');
    signal candidate_er : dv_array := (others => '0');
    signal previous     : byte_array := (others => (others => '0'));
    signal locked       : natural range 0 to 3 := 3;
    signal in_frame     : boolean := false;

begin

    alignment <= locked;

    process(clock)
        variable c_byte : byte_array;
        variable c_dv, c_er : dv_array;
        variable any_dv : boolean;
    begin
        if rising_edge(clock) then
            hi_d <= rgmii_in.hi;
            lo_d <= rgmii_in.lo;

            c_byte(0) := rgmii_in.lo(3 downto 0) & rgmii_in.hi(3 downto 0);
            c_dv(0)   := rgmii_in.hi(4);
            c_er(0)   := rgmii_in.hi(4) xor rgmii_in.lo(4);
            c_byte(1) := rgmii_in.lo(3 downto 0) & hi_d(3 downto 0);
            c_dv(1)   := hi_d(4);
            c_er(1)   := hi_d(4) xor rgmii_in.lo(4);
            c_byte(2) := lo_d(3 downto 0) & rgmii_in.hi(3 downto 0);
            c_dv(2)   := rgmii_in.hi(4);
            c_er(2)   := rgmii_in.hi(4) xor lo_d(4);

            candidate    <= c_byte;
            candidate_dv <= c_dv;
            candidate_er <= c_er;
            previous     <= candidate;

            gmii_out       <= gmii_idle;
            frame_is_ended <= false;

            if not in_frame then
                for i in 0 to 2 loop
                    if candidate_dv(i) = '1' and candidate(i) = start_of_frame_byte and previous(i) = preamble_byte then
                        locked   <= i;
                        in_frame <= true;
                        exit;
                    end if;
                end loop;
            else
                if candidate_dv(locked) = '1' then
                    gmii_out <= (data => candidate(locked), is_valid => true, is_error => candidate_er(locked) = '1');
                else
                    in_frame       <= false;
                    frame_is_ended <= true;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
