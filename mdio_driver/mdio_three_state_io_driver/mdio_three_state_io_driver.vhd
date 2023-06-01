library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.mdio_three_state_io_driver_pkg.all;

entity mdio_three_state_io_driver is
    port (
        mdio_three_state_io_driver_FPGA_inout : inout mdio_three_state_io_driver_FPGA_inout_record;
        mdio_three_state_io_driver_data_in    : in mdio_three_state_io_driver_data_input_group;
        mdio_three_state_io_driver_data_out   : out mdio_three_state_io_driver_data_output_group
    );
end entity;

architecture rtl of mdio_three_state_io_driver is

    -- cyclone 10 lp 3 state io architecture

begin
    --------------------------------------------------
    mdio_bidirectional_io_selection : process(mdio_three_state_io_driver_data_in, mdio_three_state_io_driver_FPGA_inout)
    begin
        if mdio_three_state_io_driver_data_in.direction_is_out_when_1 = '0' then
            mdio_three_state_io_driver_FPGA_inout.MDIO_inout_data <= 'Z';
            mdio_three_state_io_driver_data_out.io_input_data <= mdio_three_state_io_driver_FPGA_inout.MDIO_inout_data;
        else
            mdio_three_state_io_driver_FPGA_inout.MDIO_inout_data <= mdio_three_state_io_driver_data_in.io_output_data;
            mdio_three_state_io_driver_data_out.io_input_data <= mdio_three_state_io_driver_FPGA_inout.MDIO_inout_data;
        end if;
    end process mdio_bidirectional_io_selection;	

end rtl;
