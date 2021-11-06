library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_frame_ram_read_pkg.all;
    use work.ethernet_frame_ram_write_pkg.all;

package ethernet_frame_ram_pkg is

------------------------------------------------------------------------
    type ethernet_frame_ram_clock_group is record
        write_clock : std_logic;
        read_clock : std_logic;
    end record;
    
------------------------------------------------------------------------
    type ethernet_frame_ram_data_input_group is record
        ram_write_control_port : ram_write_control_group;
        ram_read_control_port  : ram_read_control_group;
    end record;

------------------------------------------------------------------------
    type ethernet_frame_ram_data_output_group is record
        ram_read_port_data_out : ram_read_output_group;
    end record;
------------------------------------------------------------------------
    
    component ethernet_frame_ram is
        port (
            ethernet_frame_ram_clocks   : in ethernet_frame_ram_clock_group;
            ethernet_frame_ram_data_in  : in ethernet_frame_ram_data_input_group;
            ethernet_frame_ram_data_out : out ethernet_frame_ram_data_output_group
        );
    end component ethernet_frame_ram;


    -- signal ethernet_frame_ram_clocks   : ethernet_frame_ram_clock_group;
    -- signal ethernet_frame_ram_data_in  : ethernet_frame_ram_data_input_group;
    -- signal ethernet_frame_ram_data_out : ethernet_frame_ram_data_output_group
    
    -- u_ethernet_frame_ram : ethernet_frame_ram
    -- port map( ethernet_frame_ram_clocks,
    --	  ethernet_frame_ram_data_in,
    --	  ethernet_frame_ram_data_out);

end package ethernet_frame_ram_pkg;
