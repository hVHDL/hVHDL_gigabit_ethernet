library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.mdio_driver_internal_pkg.all;
    use work.mdio_driver_pkg.all;
    use work.mdio_three_state_io_driver_pkg.all;

entity mdio_driver is
    port (
        clock : in std_logic;
        mdio_driver_FPGA_out   : out mdio_driver_FPGA_output_group;
        mdio_driver_FPGA_inout : inout mdio_driver_FPGA_three_state_record;
        mdio_driver_data_in    : in mdio_driver_data_input_group;
        mdio_driver_data_out   : out mdio_driver_data_output_group
    );
end mdio_driver;

architecture rtl of mdio_driver is

    alias core_clock is clock;
    signal mdio_transmit_control : mdio_transmit_control_group := mdio_transmit_control_init;

    signal mdio_three_state_io_driver_data_in    : mdio_three_state_io_driver_data_input_group;
    signal mdio_three_state_io_driver_data_out   : mdio_three_state_io_driver_data_output_group;

------------------------------------------------------------------------
begin

------------------------------------------------------------------------
    mdio_driver_FPGA_out.MDIO_clock <= mdio_transmit_control.mdio_clock;

    mdio_driver_data_out <= (
                                mdio_write_is_ready => mdio_transmit_control.mdio_write_is_ready,
                                mdio_read_is_ready  => mdio_transmit_control.mdio_read_is_ready,
                                data_from_mdio      => mdio_transmit_control.mdio_data_receive_register,
                                mdio_read_when_1    => mdio_transmit_control.MDIO_io_direction_is_out_when_1
                            ); 

------------------------------------------------------------------------
    mdio_io_driver : process(core_clock, mdio_driver_data_in)
    begin
        if rising_edge(core_clock) then
            create_mdio_driver(mdio_transmit_control, mdio_three_state_io_driver_data_out.io_input_data); 

        end if; --rising_edge
        mdio_transmit_control.mdio_driver_interface <= (
            mdio_data_read_is_requested  => mdio_driver_data_in.mdio_data_read_is_requested  ,
            mdio_data_write_is_requested => mdio_driver_data_in.mdio_data_write_is_requested ,
            data_to_mdio                 => mdio_driver_data_in.data_to_mdio                 ,
            phy_address                  => mdio_driver_data_in.phy_address                  ,
            phy_register_address         => mdio_driver_data_in.phy_register_address        );
    end process mdio_io_driver;	

------------------------------------------------------------------------
    mdio_three_state_io_driver_data_in <= (io_output_data         => mdio_transmit_control.mdio_transmit_register(mdio_transmit_control.mdio_transmit_register'left),
                                          direction_is_out_when_1 => mdio_transmit_control.MDIO_io_direction_is_out_when_1);
    u_mdio_three_state_io_driver : mdio_three_state_io_driver
    port map( 
          mdio_driver_FPGA_inout.mdio_three_state_io_driver_FPGA_inout,
    	  mdio_three_state_io_driver_data_in,
    	  mdio_three_state_io_driver_data_out); 

------------------------------------------------------------------------
end rtl;
