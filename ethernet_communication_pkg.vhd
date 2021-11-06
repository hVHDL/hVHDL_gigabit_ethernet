library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_pkg.all;
    use work.ethernet_frame_ram_pkg.all;
    use work.ethernet_frame_ram_read_pkg.all;
    use work.ethernet_frame_ram_pkg.all;
    use work.network_protocol_header_pkg.all;

package ethernet_communication_pkg is

    type ethernet_communication_FPGA_input_group is record
        ethernet_FPGA_in : ethernet_FPGA_input_group;
    end record;
    
    type ethernet_communication_FPGA_output_group is record
        ethernet_FPGA_out : ethernet_FPGA_output_group;
    end record;

    type ethernet_communication_FPGA_inout_record is record
        ethernet_FPGA_inout : ethernet_FPGA_inout_record;
    end record;
    
    type ethernet_communication_data_input_group is record
        ethernet_data_in            : ethernet_data_input_group;
        receiver_ram_read_control_port : ram_read_control_group;
    end record;
    
    type ethernet_communication_data_output_group is record
        ethernet_data_out          : ethernet_data_output_group;
        ethernet_protocol_data_out : network_protocol_data_output_group;
        frame_ram_data_out         : ram_read_output_group;
    end record;
    
    component ethernet_communication is
        port (
            ethernet_communication_clocks     : in  ethernet_clock_group;
            ethernet_communication_FPGA_in    : in  ethernet_communication_FPGA_input_group;
            ethernet_communication_FPGA_out   : out ethernet_communication_FPGA_output_group;
            ethernet_communication_FPGA_inout : inout ethernet_communication_FPGA_inout_record;
            ethernet_communication_data_in    : in  ethernet_communication_data_input_group;
            ethernet_communication_data_out   : out ethernet_communication_data_output_group
        );
    end component ethernet_communication;
    
    -- signal ethernet_communication_clocks     : ethernet_communication_clock_group;
    -- signal ethernet_communication_FPGA_in    : ethernet_communication_FPGA_input_group;
    -- signal ethernet_communication_FPGA_out   : ethernet_communication_FPGA_output_group;
    -- signal ethernet_communication_FPGA_inout : ethernet_communication_FPGA_inout_record;
    -- signal ethernet_communication_data_in    : ethernet_communication_data_input_group;
    -- signal ethernet_communication_data_out   : ethernet_communication_data_output_group;
    
    -- u_ethernet_communication : ethernet_communication
    -- port map( ethernet_communication_clocks,
    -- 	  ethernet_communication_FPGA_in,
    --	  ethernet_communication_FPGA_out,
    --	  ethernet_communication_data_in,
    --	  ethernet_communication_data_out);
    

end package ethernet_communication_pkg;

