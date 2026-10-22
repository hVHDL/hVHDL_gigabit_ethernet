library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- Copies a multi bit value from the source clock domain to the destination domain with a
-- toggle handshake. A new snapshot is requested as soon as the previous one has arrived,
-- so the destination sees a consistent value that is at most a few clocks old.
entity cdc_snapshot is
    generic(g_width : positive);
    port(
        source_clock      : in std_logic;
        source_data       : in std_logic_vector(g_width-1 downto 0);
        destination_clock : in std_logic;
        destination_data  : out std_logic_vector(g_width-1 downto 0)
    );
end entity cdc_snapshot;

architecture rtl of cdc_snapshot is
    signal request        : std_logic := '0';
    signal request_sync   : std_logic_vector(2 downto 0) := (others => '0');
    signal acknowledge    : std_logic := '0';
    signal acknowledge_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal held_data      : std_logic_vector(g_width-1 downto 0) := (others => '0');

    attribute async_reg : boolean;
    attribute async_reg of request_sync, acknowledge_sync : signal is true;
begin

    source : process(source_clock)
    begin
        if rising_edge(source_clock) then
            request_sync <= request_sync(1 downto 0) & request;
            if request_sync(2) /= request_sync(1) then
                held_data   <= source_data;
                acknowledge <= not acknowledge;
            end if;
        end if;
    end process;

    destination : process(destination_clock)
    begin
        if rising_edge(destination_clock) then
            acknowledge_sync <= acknowledge_sync(1 downto 0) & acknowledge;
            if acknowledge_sync(2) = request then
                -- held_data has been stable since the acknowledge toggled
                destination_data <= held_data;
                request          <= not request;
            end if;
        end if;
    end process;

end architecture rtl;
