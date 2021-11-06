library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_frame_ram_read_pkg.all;
    use work.network_protocol_header_pkg.all;

entity network_protocol is
    port (
        network_protocol_clocks   : in network_protocol_clock_group;
        network_protocol_data_in  : in network_protocol_data_input_group;
        network_protocol_data_out : out network_protocol_data_output_group
    );
end entity network_protocol;
