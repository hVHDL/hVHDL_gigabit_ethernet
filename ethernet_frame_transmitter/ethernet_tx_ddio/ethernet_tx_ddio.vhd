library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_tx_ddio_pkg.all;

entity ethernet_tx_ddio is
    port (
        ethernet_tx_ddio_clocks   : in ethernet_tx_ddr_clock_group;
        ethernet_tx_ddio_FPGA_out : out ethernet_tx_ddio_FPGA_output_group;
        ethernet_tx_ddio_data_in  : in ethernet_tx_ddio_data_input_group
    );
end entity;

-- add proper architecture for cl10 compile
