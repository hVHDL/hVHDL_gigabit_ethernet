library ieee;
    use ieee.std_logic_1164.all;

-- Single cycle pulse from the source to the destination clock domain.
-- Pulses closer together than a few destination clocks are merged.
entity cdc_pulse is
    port(
        source_clock      : in std_logic;
        source_pulse      : in boolean;
        destination_clock : in std_logic;
        destination_pulse : out boolean
    );
end entity cdc_pulse;

architecture rtl of cdc_pulse is
    signal toggle      : std_logic := '0';
    signal toggle_sync : std_logic_vector(2 downto 0) := (others => '0');
    attribute async_reg : boolean;
    attribute async_reg of toggle_sync : signal is true;
begin
    process(source_clock)
    begin
        if rising_edge(source_clock) then
            if source_pulse then
                toggle <= not toggle;
            end if;
        end if;
    end process;

    process(destination_clock)
    begin
        if rising_edge(destination_clock) then
            toggle_sync       <= toggle_sync(1 downto 0) & toggle;
            destination_pulse <= toggle_sync(2) /= toggle_sync(1);
        end if;
    end process;
end architecture rtl;
