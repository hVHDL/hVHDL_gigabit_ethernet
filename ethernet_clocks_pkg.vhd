library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ethernet_clocks_pkg is

    type ethernet_rx_ddr_clock_group is record
        rx_ddr_clock : std_logic;
        reset_n       : std_logic;
    end record;

    type ethernet_tx_ddr_clock_group is record
        tx_ddr_clock : std_logic;
        reset_n       : std_logic;
    end record;

    type ethernet_clock_group is record
        core_clock    : std_logic;
        reset_n       : std_logic;
        rx_ddr_clocks : ethernet_rx_ddr_clock_group;
        tx_ddr_clocks : ethernet_tx_ddr_clock_group;
    end record;

end package ethernet_clocks_pkg;
