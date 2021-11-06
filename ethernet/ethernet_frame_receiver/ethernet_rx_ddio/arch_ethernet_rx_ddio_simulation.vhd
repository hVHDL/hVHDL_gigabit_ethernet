library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_rx_ddio_pkg.all;

-- entity ethernet_rx_ddio is
--     port (
--         ethernet_rx_ddio_clocks   : in ethernet_clocks;
--         ethernet_rx_ddio_FPGA_in  : out ethernet_rx_ddio_FPGA_output_group;
--         ethernet_rx_ddio_data_out : out ethernet_rx_ddio_data_output_group
--     );
-- end entity;

-- add proper architecture for cl10 compile

architecture simulation of ethernet_rx_ddio is

    alias ddio_rx_clock is ethernet_rx_ddio_clocks.rx_ddr_clock;
    alias ddio_fpga_in is ethernet_rx_ddio_fpga_in.ethernet_rx_ddio_in;
    alias received_ethernet_byte is ethernet_rx_ddio_data_out.ethernet_rx_byte;

begin

    ddio_driver_simulation : process(ddio_rx_clock)
        
    begin
        if rising_edge(ddio_rx_clock) then
            -- ethernet_rx_ddio_data_out.rx_ctl(1) <= ddio_fpga_in(4);
            received_ethernet_byte(7) <= ddio_fpga_in(3);
            received_ethernet_byte(6) <= ddio_fpga_in(2);
            received_ethernet_byte(5) <= ddio_fpga_in(1);
            received_ethernet_byte(4) <= ddio_fpga_in(0);
        end if; --rising_edge

        if falling_edge(ddio_rx_clock) then
            -- ethernet_rx_ddio_data_out.rx_ctl(0) <= ddio_fpga_in(4);
            received_ethernet_byte(3) <= ddio_fpga_in(3);
            received_ethernet_byte(2) <= ddio_fpga_in(2);
            received_ethernet_byte(1) <= ddio_fpga_in(1);
            received_ethernet_byte(0) <= ddio_fpga_in(0);
        end if; --falling_edge

    end process ddio_driver_simulation;	

end simulation;
