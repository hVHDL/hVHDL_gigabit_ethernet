library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;

-- GMII byte stream to RGMII DDIO halves. TX_CLK is produced by a DDIO output with
-- hi = '1' and lo = '0' from the same clock, the PHY adds the TX clock skew.
-- delay_lo_half moves the falling edge nibble one clock later, in case the DDIO output
-- registers pair the halves differently than assumed.
entity rgmii_tx is
    port(
        clock         : in std_logic;
        gmii_in       : in gmii_record;
        delay_lo_half : in boolean;
        rgmii_out     : out rgmii_ddio_record;
        tx_clock_out  : out rgmii_ddio_record
    );
end entity rgmii_tx;

architecture rtl of rgmii_tx is
    signal lo_delayed : std_logic_vector(4 downto 0) := (others => '0');
begin

    tx_clock_out <= (hi => (others => '1'), lo => (others => '0'));

    process(clock)
        variable en, er : std_logic;
        variable lo     : std_logic_vector(4 downto 0);
    begin
        if rising_edge(clock) then
            en := '0';
            er := '0';
            if gmii_in.is_valid then en := '1'; end if;
            if gmii_in.is_error then er := '1'; end if;
            lo := (en xor er) & gmii_in.data(7 downto 4);
            lo_delayed   <= lo;
            rgmii_out.hi <= en & gmii_in.data(3 downto 0);
            if delay_lo_half then
                rgmii_out.lo <= lo_delayed;
            else
                rgmii_out.lo <= lo;
            end if;
        end if;
    end process;

end architecture rtl;
