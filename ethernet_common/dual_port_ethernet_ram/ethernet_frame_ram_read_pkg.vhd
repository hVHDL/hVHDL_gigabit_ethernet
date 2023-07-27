library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ethernet_frame_ram_read_pkg is
------------------------------------------------------------------------
    type ram_read_control_record is record
        address : std_logic_vector(10 downto 0);
        read_is_enabled_when_1 : std_logic;
    end record; 

    -- prevent syntax failures
    alias ram_read_control_group is ram_read_control_record;
    constant init_ram_read_port : ram_read_control_record := ((others => '0'), '0');
------------------------------------------------------------------------
    type ram_read_output_record is record
        ram_is_ready : boolean;
        byte_address : std_logic_vector(10 downto 0);
        byte_from_ram : std_logic_vector(7 downto 0);
    end record;

    alias ram_read_output_group is ram_read_output_record;
    constant ram_read_output_init : ram_read_output_group := (false, (others => '0'), (others => '0'));
    alias init_ram_read_output is ram_read_output_init;
------------------------------------------------------------------------ 
    procedure init_ram_read_output_port (
        signal output_port : out ram_read_output_record);
------------------------------------------------------------------------ 
    function "+" ( left, right : ram_read_control_record)
        return ram_read_control_record; 

------------------------------------------------------------------------ 
    procedure init_ram_read (
        signal ram_read_control_port : out ram_read_control_record);
------------------------------------------------------------------------
    procedure read_data_from_ram (
        signal ram_read_control_port : out ram_read_control_record;
        offset : natural;
        address : natural);
------------------------------------------------------------------------
    procedure read_data_from_ram (
        signal ram_read_control_port : out ram_read_control_record;
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
    type ram_reader_record is record
        number_addresses_left_to_read : natural range 0 to 2**11-1;
        ram_read_address : natural range 0 to 2**11-1;
        ram_buffering_is_complete : boolean;
        ram_offset : natural range 0 to 2**11-1;
    end record;

    constant init_ram_reader : ram_reader_record := (0, 0, false, 0);
------------------------------------------------------------------------
    procedure create_ram_reader (
        signal self : inout ram_reader_record;
        signal ram_read_control_port : out ram_read_control_record;
        ram_output_port : in ram_read_output_group;
        signal ram_shift_register : inout std_logic_vector);
------------------------------------------------------------------------
    procedure load_ram_with_offset_to_shift_register (
        signal self : inout  ram_reader_record;
        start_address : natural;
        number_of_ram_addresses_to_be_read : natural);
------------------------------------------------------------------------
    function ram_is_buffered_to_shift_register ( self : ram_reader_record)
        return boolean;
------------------------------------------------------------------------
end package ethernet_frame_ram_read_pkg;


package body ethernet_frame_ram_read_pkg is
------------------------------------------------------------------------
    procedure init_ram_read
    (
        signal ram_read_control_port : out ram_read_control_record
    ) is
    begin
        ram_read_control_port.read_is_enabled_when_1 <= '0'; 
        ram_read_control_port.address <= (others => '0');
    end init_ram_read;

------------------------------------------------------------------------
    procedure read_data_from_ram
    (
        signal ram_read_control_port : out ram_read_control_record;
        address : natural
    ) is
    begin
        ram_read_control_port.read_is_enabled_when_1 <= '1';
        ram_read_control_port.address <= std_logic_vector(to_unsigned(address, 11));

    end read_data_from_ram;
------------------------------------------------------------------------
    procedure read_data_from_ram
    (
        signal ram_read_control_port : out ram_read_control_record;
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
    procedure init_ram_read_output_port
    (
        signal output_port : out ram_read_output_record
    ) is
    begin
        output_port <= init_ram_read_output;
    end init_ram_read_output_port;
------------------------------------------------------------------------
    procedure create_ram_reader
    (
        signal self                  : inout ram_reader_record;
        signal ram_read_control_port : out ram_read_control_record;
        ram_output_port              : in ram_read_output_group;
        signal ram_shift_register    : inout std_logic_vector
    ) is
    begin
        init_ram_read(ram_read_control_port);
        load_ram_to_shift_register(ram_output_port, ram_shift_register);

        if self.ram_read_address < self.ram_offset then
            self.ram_read_address <= self.ram_read_address + 1;
            read_data_from_ram(ram_read_control_port, self.ram_read_address);
        end if;

        self.ram_buffering_is_complete <= false;
        if ram_data_is_ready(ram_output_port) then
            if self.number_addresses_left_to_read > 0 then
                self.number_addresses_left_to_read <= self.number_addresses_left_to_read - 1;
            end if;
            if self.number_addresses_left_to_read = 1 then
                self.ram_buffering_is_complete <= true;
            end if;
        end if; 
        
    end create_ram_reader; 

------------------------------------------------------------------------
    procedure load_ram_with_offset_to_shift_register
    (
        signal self : inout  ram_reader_record;
        start_address : natural;
        number_of_ram_addresses_to_be_read : natural
    ) is
    begin
        self.ram_read_address              <= start_address;
        self.number_addresses_left_to_read <= number_of_ram_addresses_to_be_read;
        self.ram_offset                    <= start_address + number_of_ram_addresses_to_be_read;

    end load_ram_with_offset_to_shift_register;
------------------------------------------------------------------------
    function ram_is_buffered_to_shift_register
    (
        self : ram_reader_record
    )
    return boolean
    is
    begin
       return self.ram_buffering_is_complete; 
    end ram_is_buffered_to_shift_register;
------------------------------------------------------------------------

    function "+"
    (
        left, right : ram_read_control_record
    )
    return ram_read_control_record
    is
        variable combined_port : ram_read_control_record;
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
