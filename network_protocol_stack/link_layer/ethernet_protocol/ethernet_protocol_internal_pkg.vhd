library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_frame_ram_read_pkg.all;

package ethernet_protocol_internal_pkg is

    constant ethertype_ipv4 : std_logic_vector(15 downto 0) := x"0800";
    constant ethernet_frame_length : natural := 14;
    constant ethertype_address : natural := 14;

end package ethernet_protocol_internal_pkg;


package body ethernet_protocol_internal_pkg is

------------------------------------------------------------------------
end package body ethernet_protocol_internal_pkg; 
