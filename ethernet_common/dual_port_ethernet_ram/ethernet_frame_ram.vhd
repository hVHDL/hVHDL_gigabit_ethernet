library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_frame_ram_pkg.all;

entity ethernet_frame_ram is
    port (
        ethernet_frame_ram_clocks   : in ethernet_frame_ram_clock_group;
        ethernet_frame_ram_data_in  : in ethernet_frame_ram_data_input_group;
        ethernet_frame_ram_data_out : out ethernet_frame_ram_data_output_group
    );
end entity ethernet_frame_ram;
