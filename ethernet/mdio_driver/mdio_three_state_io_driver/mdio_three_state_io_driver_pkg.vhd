library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package mdio_three_state_io_driver_pkg is

    type mdio_three_state_io_driver_FPGA_inout_record is record
        MDIO_inout_data : std_logic;
    end record;
    
    type mdio_three_state_io_driver_data_input_group is record
        direction_is_out_when_1 : std_logic;
        io_output_data          : std_logic;
    end record;
    
    type mdio_three_state_io_driver_data_output_group is record
        io_input_data : std_logic;
    end record;
    
    component mdio_three_state_io_driver is
        port (
            mdio_three_state_io_driver_FPGA_inout : inout mdio_three_state_io_driver_FPGA_inout_record;
            mdio_three_state_io_driver_data_in    : in mdio_three_state_io_driver_data_input_group;
            mdio_three_state_io_driver_data_out   : out mdio_three_state_io_driver_data_output_group
        );
    end component mdio_three_state_io_driver;
    
    -- signal mdio_three_state_io_driver_FPGA_inout : inout mdio_three_state_io_driver_FPGA_inout_record;
    -- signal mdio_three_state_io_driver_data_in    : mdio_three_state_io_driver_data_input_group;
    -- signal mdio_three_state_io_driver_data_out   : mdio_three_state_io_driver_data_output_group
    
    -- u_mdio_three_state_io_driver : mdio_three_state_io_driver
    -- port map( 
    --    mdio_three_state_io_driver_FPGA_inout : inout mdio_three_state_io_driver_FPGA_inout_record;
    --	  mdio_three_state_io_driver_data_in,
    --	  mdio_three_state_io_driver_data_out);
    

end package mdio_three_state_io_driver_pkg;

