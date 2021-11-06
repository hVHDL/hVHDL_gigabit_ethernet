library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_rx_ddio_pkg.all;
    use work.ethernet_frame_ram_write_pkg.all;

package ethernet_frame_receiver_pkg is

    type ethernet_frame_receiver_FPGA_input_group is record
        ethernet_rx_ddio_FPGA_in : ethernet_rx_ddio_FPGA_input_group;
    end record;
    
    type ethernet_frame_receiver_data_output_group is record
        ram_write_control_port       : ram_write_control_group;
        toggle_data_has_been_written : std_logic;
    end record;
    
    component ethernet_frame_receiver is
        port (
            ethernet_frame_receiver_clocks : in ethernet_rx_ddr_clock_group; 
            ethernet_frame_receiver_FPGA_in : in ethernet_frame_receiver_FPGA_input_group;
            ethernet_frame_receiver_data_out : out ethernet_frame_receiver_data_output_group
        );
    end component ethernet_frame_receiver;
    
    -- signal ethernet_frame_receiver_clocks   : ethernet_frame_receiver_clock_group;
    -- signal ethernet_frame_receiver_FPGA_in  : ethernet_frame_receiver_FPGA_input_group;
    -- signal ethernet_frame_receiver_data_in  : ethernet_frame_receiver_data_input_group;
    -- signal ethernet_frame_receiver_data_out : ethernet_frame_receiver_data_output_group
    
    -- u_ethernet_frame_receiver : ethernet_frame_receiver
    -- port map( ethernet_frame_receiver_clocks,
    -- 	  ethernet_frame_receiver_FPGA_in,
    --	  ethernet_frame_receiver_data_in,
    --	  ethernet_frame_receiver_data_out);

end package ethernet_frame_receiver_pkg;
