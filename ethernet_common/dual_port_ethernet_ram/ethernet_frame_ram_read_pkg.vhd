library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ethernet_frame_ram_read_pkg is
------------------------------------------------------------------------
        type ram_read_control_group is record
            address : std_logic_vector(10 downto 0);
            read_is_enabled_when_1 : std_logic;
        end record; 
------------------------------------------------------------------------
        type ram_read_output_group is record
            ram_is_ready : boolean;
            byte_address : std_logic_vector(10 downto 0);
            byte_from_ram : std_logic_vector(7 downto 0);
        end record;

    constant ram_read_output_init : ram_read_output_group := (false, (others => '0'), (others => '0'));
------------------------------------------------------------------------ 
    function "+" ( left, right : ram_read_control_group)
        return ram_read_control_group; 

------------------------------------------------------------------------ 
    procedure init_ram_read (
        signal ram_read_control_port : out ram_read_control_group);
------------------------------------------------------------------------
    procedure read_data_from_ram (
        signal ram_read_control_port : out ram_read_control_group;
        offset : natural;
        address : natural);
------------------------------------------------------------------------
    procedure read_data_from_ram (
        signal ram_read_control_port : out ram_read_control_group;
        address : natural);
------------------------------------------------------------------------
    function get_ram_data ( ram_read_control_port_data_out : ram_read_output_group)
        return std_logic_vector;
------------------------------------------------------------------------
    function ram_data_is_ready ( ram_read_control_port_data_out : ram_read_output_group)
        return boolean;
------------------------------------------------------------------------
    procedure load_ram_to_shift_register (
        ram_output : in ram_read_output_group;
        signal ram_shift_register : inout std_logic_vector);
------------------------------------------------------------------------
    function get_ram_address ( ram_data_out : ram_read_output_group)
        return natural;

------------------------------------------------------------------------
------------------------------------------------------------------------
    type ram_reader is record
        number_addresses_left_to_read : natural range 0 to 2**11-1;
        ram_read_address : natural range 0 to 2**11-1;
        ram_buffering_is_complete : boolean;
        ram_offset : natural range 0 to 2**11-1;
    end record;

    constant ram_reader_init : ram_reader := (0, 0, false, 0);
------------------------------------------------------------------------
    procedure create_ram_read_controller (
        signal ram_read_control_port : out ram_read_control_group;
        ram_output_port : in ram_read_output_group;
        signal ram_controller : inout ram_reader;
        signal ram_shift_register : inout std_logic_vector);
------------------------------------------------------------------------
    procedure load_ram_with_offset_to_shift_register (
        signal ram_controller : inout  ram_reader;
        start_address : natural;
        number_of_ram_addresses_to_be_read : natural);
------------------------------------------------------------------------
    function ram_is_buffered_to_shift_register ( ram_controller : ram_reader)
        return boolean;

------------------------------------------------------------------------
end package ethernet_frame_ram_read_pkg;


package body ethernet_frame_ram_read_pkg is
------------------------------------------------------------------------
    procedure init_ram_read
    (
        signal ram_read_control_port : out ram_read_control_group
    ) is
    begin
        ram_read_control_port.read_is_enabled_when_1 <= '0'; 
        ram_read_control_port.address <= (others => '0');
    end init_ram_read;

------------------------------------------------------------------------
    procedure read_data_from_ram
    (
        signal ram_read_control_port : out ram_read_control_group;
        address : natural
    ) is
    begin
        ram_read_control_port.read_is_enabled_when_1 <= '1';
        ram_read_control_port.address <= std_logic_vector(to_unsigned(address, 11));

    end read_data_from_ram;
------------------------------------------------------------------------
    procedure read_data_from_ram
    (
        signal ram_read_control_port : out ram_read_control_group;
        offset : natural;
        address : natural
    ) is
    begin
        ram_read_control_port.read_is_enabled_when_1 <= '1';
        ram_read_control_port.address <= std_logic_vector(to_unsigned(offset + address, 11));

    end read_data_from_ram;

------------------------------------------------------------------------
    function get_ram_data
    (
        ram_read_control_port_data_out : ram_read_output_group
    )
    return std_logic_vector 
    is
    begin
        return ram_read_control_port_data_out.byte_from_ram;
    end get_ram_data;
------------------------------------------------------------------------
    function ram_data_is_ready
    (
        ram_read_control_port_data_out : ram_read_output_group
    )
    return boolean
    is
    begin
        return ram_read_control_port_data_out.ram_is_ready;
        
    end ram_data_is_ready;
------------------------------------------------------------------------
    procedure load_ram_to_shift_register
    (
        ram_output : in ram_read_output_group;
        signal ram_shift_register : inout std_logic_vector
    ) is
    begin
        if ram_data_is_ready(ram_output) then
            ram_shift_register <=  ram_shift_register(ram_shift_register'left-8 downto 0) & get_ram_data(ram_output);
        end if;

    end load_ram_to_shift_register;

------------------------------------------------------------------------
    procedure create_ram_read_controller
    (
        signal ram_read_control_port : out ram_read_control_group;
        ram_output_port : in ram_read_output_group;
        signal ram_controller : inout ram_reader;
        signal ram_shift_register : inout std_logic_vector
    ) is
    begin
        init_ram_read(ram_read_control_port);
        load_ram_to_shift_register(ram_output_port, ram_shift_register);

        if ram_controller.ram_read_address < ram_controller.ram_offset then
            ram_controller.ram_read_address <= ram_controller.ram_read_address + 1;
            read_data_from_ram(ram_read_control_port, ram_controller.ram_read_address);
        end if;

        ram_controller.ram_buffering_is_complete <= false;
        if ram_data_is_ready(ram_output_port) then
            ram_controller.number_addresses_left_to_read <= ram_controller.number_addresses_left_to_read - 1;
            if ram_controller.number_addresses_left_to_read = 1 then
                ram_controller.ram_buffering_is_complete <= true;
            end if;
        end if; 
        
    end create_ram_read_controller; 

------------------------------------------------------------------------
    procedure load_ram_with_offset_to_shift_register
    (
        signal ram_controller : inout  ram_reader;
        start_address : natural;
        number_of_ram_addresses_to_be_read : natural
    ) is
    begin
        ram_controller.ram_read_address              <= start_address;
        ram_controller.number_addresses_left_to_read <= number_of_ram_addresses_to_be_read;
        ram_controller.ram_offset                    <= start_address + number_of_ram_addresses_to_be_read;

    end load_ram_with_offset_to_shift_register;
------------------------------------------------------------------------
    function ram_is_buffered_to_shift_register
    (
        ram_controller : ram_reader
    )
    return boolean
    is
    begin
       return ram_controller.ram_buffering_is_complete; 
    end ram_is_buffered_to_shift_register;
------------------------------------------------------------------------

    function "+"
    (
        left, right : ram_read_control_group
    )
    return ram_read_control_group
    is
        variable combined_port : ram_read_control_group;
    begin

        combined_port.address := left.address OR right.address;
        combined_port.read_is_enabled_when_1 := left.read_is_enabled_when_1 OR right.read_is_enabled_when_1;

        return combined_port;
        
    end "+";
------------------------------------------------------------------------
    function get_ram_address
    (
        ram_data_out : ram_read_output_group
    )
    return natural
    is
    begin
        return to_integer(unsigned(ram_data_out.byte_address));
    end get_ram_address;
------------------------------------------------------------------------

end package body ethernet_frame_ram_read_pkg; 
