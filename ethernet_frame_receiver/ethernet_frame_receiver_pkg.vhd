library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_rx_ddio_pkg.all;
    use work.PCK_CRC32_D8.all;
    use work.ethernet_frame_ram_write_pkg.all;

package ethernet_frame_receiver_pkg is

    type ethernet_receiver_record is record
        shift_register           : std_logic_vector(15 downto 0);
        crc32                    : std_logic_vector(31 downto 0);
        frame_detected           : boolean;
        receiver_ram_address     : natural;
        crc_counter              : natural range 0 to 7;
        number_of_bytes_received : natural;
        frame_was_received       : boolean;
        rx_is_active             : boolean;
        inverted_byte            : std_logic_vector(7 downto 0);
    end record;

    constant init_ethernet_receiver : ethernet_receiver_record := ((others => '0'), (others => '1'), false, 0, 0, 0,false, false, (others => '0'));
------------------------------------------------------------------------
    procedure create_ethernet_receiver (
        signal self      : inout ethernet_receiver_record;
        enet_rx_ddio     : in ethernet_rx_ddio_data_output_group);

------------------------------------------------------------------------
    function receiver_is_active ( self : ethernet_receiver_record)
        return boolean;

------------------------------------------------------------------------
    function get_received_byte ( self : ethernet_receiver_record)
        return std_logic_vector;

------------------------------------------------------------------------
    function get_received_byte_index ( self : ethernet_receiver_record )
        return natural;
------------------------------------------------------------------------
    procedure write_crc_to_receiver_ram (
        signal self : inout ethernet_receiver_record;
        signal ram_write : out ram_write_control_record);
------------------------------------------------------------------------
    procedure count_only_frame_bytes (
        signal self : inout ethernet_receiver_record);
------------------------------------------------------------------------
    procedure count_preamble_and_frame_bytes (
        signal self : inout ethernet_receiver_record);
------------------------------------------------------------------------
    procedure write_ethernet_frame_to_ram (
        signal self      : inout ethernet_receiver_record;
        signal ram_write : out ram_write_control_record);
------------------------------------------------------------------------

end package ethernet_frame_receiver_pkg;

package body ethernet_frame_receiver_pkg is

    procedure create_ethernet_receiver
    (
        signal self      : inout ethernet_receiver_record;
        enet_rx_ddio     : in ethernet_rx_ddio_data_output_group
    ) is
        variable enet_byte : std_logic_vector(7 downto 0);
        variable inverted_enet_byte : std_logic_vector(7 downto 0);
    begin

        self.rx_is_active <= ethernet_rx_is_active(enet_rx_ddio);
        if ethernet_rx_is_active(enet_rx_ddio) or self.rx_is_active then
            self.shift_register <= self.shift_register(7 downto 0) & get_byte(enet_rx_ddio);
            self.inverted_byte  <= get_byte_with_inverted_bit_order(enet_rx_ddio);

            enet_byte          := self.shift_register(7 downto 0);
            inverted_enet_byte := self.inverted_byte;

            if self.shift_register = x"aaab" then
                self.frame_detected <= true;
            end if;

            if self.frame_detected then
                self.crc32 <= nextCRC32_D8(enet_byte, self.crc32);
            end if;

            self.crc_counter <= 4;
        else
            self.frame_detected <= false;
        end if;
    ------------------------------
        
    end create_ethernet_receiver;

------------------------------------------------------------------------
    function receiver_is_active
    (
        self : ethernet_receiver_record
    )
    return boolean
    is
    begin
        return self.rx_is_active;
    end receiver_is_active;
------------------------------------------------------------------------
    function get_received_byte
    (
        self : ethernet_receiver_record
    )
    return std_logic_vector 
    is
        variable return_value : std_logic_vector(7 downto 0);
        
    begin
        if self.frame_detected then
            return_value := self.inverted_byte;
        else
            return_value := self.shift_register(7 downto 0);
        end if;

        return return_value;
        
    end get_received_byte;
------------------------------------------------------------------------
    function get_received_byte_index
    (
        self : ethernet_receiver_record 
    )
    return natural
    is
    begin
        return self.receiver_ram_address;
    end get_received_byte_index;
------------------------------------------------------------------------
    procedure count_only_frame_bytes
    (
        signal self : inout ethernet_receiver_record
    ) is
    begin
        if self.frame_detected then
            if self.receiver_ram_address < 2**10-1 then
                self.receiver_ram_address <= self.receiver_ram_address + 1;
            end if;
        end if;
    end count_only_frame_bytes;
------------------------------------------------------------------------
    procedure count_preamble_and_frame_bytes
    (
        signal self : inout ethernet_receiver_record
    ) is
    begin
        if receiver_is_active(self) then
            if self.receiver_ram_address < 2**10-1 then
                self.receiver_ram_address <= self.receiver_ram_address + 1;
            end if;
        end if;
    end count_preamble_and_frame_bytes;
------------------------------------------------------------------------
    procedure write_ethernet_frame_to_ram
    (
        signal self      : inout ethernet_receiver_record;
        signal ram_write : out ram_write_control_record
    ) is
    begin
        if receiver_is_active(self) then
            write_data_to_ram(ram_write, get_received_byte_index(self), get_received_byte(self));
        end if;
    end write_ethernet_frame_to_ram;
------------------------------------------------------------------------
    procedure write_crc_to_receiver_ram
    (
        signal self : inout ethernet_receiver_record;
        signal ram_write : out ram_write_control_record
    ) is
    begin
        if not receiver_is_active(self) then 
            if self.crc_counter > 0 then
                self.crc_counter <= self.crc_counter - 1;
                self.crc32 <= self.crc32(23 downto 0) & x"ff";
                write_data_to_ram(ram_write, get_received_byte_index(self), self.crc32(31 downto 24));
                self.receiver_ram_address <= self.receiver_ram_address + 1;
            end if;
        end if;
        
    end write_crc_to_receiver_ram;
------------------------------------------------------------------------
end package body ethernet_frame_receiver_pkg;
