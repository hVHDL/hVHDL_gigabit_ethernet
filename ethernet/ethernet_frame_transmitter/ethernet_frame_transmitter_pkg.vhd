library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_tx_ddio_pkg.all;

package ethernet_frame_transmitter_pkg is

    type ethernet_frame_transmitter_FPGA_output_group is record
        ethernet_tx_ddio_FPGA_out : ethernet_tx_ddio_FPGA_output_group; 
    end record;
    
    type ethernet_frame_transmitter_data_input_group is record
        clock : std_logic;
    end record;
    
    type ethernet_frame_transmitter_data_output_group is record
        clock : std_logic;
    end record;
    
    component ethernet_frame_transmitter is
        port (
            tx_ddr_clocks   : in ethernet_tx_ddr_clock_group;
            ethernet_frame_transmitter_FPGA_out : out ethernet_frame_transmitter_FPGA_output_group;
            ethernet_frame_transmitter_data_in  : in ethernet_frame_transmitter_data_input_group;
            ethernet_frame_transmitter_data_out : out ethernet_frame_transmitter_data_output_group
        );
    end component ethernet_frame_transmitter;
    
    -- signal ethernet_frame_transmitter_clocks   : ethernet_frame_transmitter_clock_group;
    -- signal ethernet_frame_transmitter_FPGA_out : ethernet_frame_transmitter_FPGA_output_group;
    -- signal ethernet_frame_transmitter_data_in  : ethernet_frame_transmitter_data_input_group;
    -- signal ethernet_frame_transmitter_data_out : ethernet_frame_transmitter_data_output_group
    
    -- u_ethernet_frame_transmitter : ethernet_frame_transmitter
    -- port map( ethernet_frame_transmitter_clocks,
    -- 	  ethernet_frame_transmitter_FPGA_in,
    --	  ethernet_frame_transmitter_FPGA_out,
    --	  ethernet_frame_transmitter_data_in,
    --	  ethernet_frame_transmitter_data_out);
    

end package ethernet_frame_transmitter_pkg;

