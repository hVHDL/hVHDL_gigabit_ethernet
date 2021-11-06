library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ethernet_frame_ram_write_pkg is

------------------------------------------------------------------------
    type ram_write_control_group is record
        address              : std_logic_vector(10 downto 0);
        byte_to_write        : std_logic_vector(7 downto 0);
        write_enabled_when_1 : std_logic;
    end record; 
------------------------------------------------------------------------
    
    procedure init_ram_write (
        signal ram_write_port : out ram_write_control_group);
------------------------------------------------------------------------
    procedure write_data_to_ram (
        signal ram_write_port : out ram_write_control_group;
        address : natural;
        byte_to_write : std_logic_vector(7 downto 0));
------------------------------------------------------------------------ 

end package ethernet_frame_ram_write_pkg;

package body ethernet_frame_ram_write_pkg is

------------------------------------------------------------------------ 
    procedure init_ram_write
    (
        signal ram_write_port : out ram_write_control_group
    ) is
    begin
        ram_write_port.write_enabled_when_1 <= '0';
        ram_write_port.address <= (others => '0');
    end init_ram_write;


------------------------------------------------------------------------ 
    procedure write_data_to_ram
    (
        signal ram_write_port : out ram_write_control_group;
        address : natural;
        byte_to_write : std_logic_vector(7 downto 0)
    ) is
    begin

        ram_write_port.write_enabled_when_1 <= '1';
        ram_write_port.byte_to_write <= byte_to_write;
        ram_write_port.address <= std_logic_vector(to_unsigned(address, 11));
        
    end write_data_to_ram;

------------------------------------------------------------------------ 
end package body ethernet_frame_ram_write_pkg; 
