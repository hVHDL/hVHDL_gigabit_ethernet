library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_rx_ddio_pkg.all;
    use work.ethernet_clocks_pkg.all;


entity ethernet_rx_ddio is
    port (
        ethernet_rx_ddio_clocks   : in ethernet_rx_ddr_clock_group;
        ethernet_rx_ddio_FPGA_in  : in ethernet_rx_ddio_FPGA_input_group;
        ethernet_rx_ddio_data_out : out ethernet_rx_ddio_data_output_group
    );
end entity;
