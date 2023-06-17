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

    procedure create_ethernet_receiver (
        signal self      : inout ethernet_receiver_record;
        enet_rx_ddio     : in ethernet_rx_ddio_data_output_group;
        signal ram_write : out ram_write_control_record);

    procedure idle_transmitter (
        signal ddio_hi, ddio_lo : out std_logic_vector(4 downto 0));

    procedure transmit_byte (
        signal ddio_hi, ddio_lo : out std_logic_vector(4 downto 0);
        byte : in std_logic_vector(7 downto 0));

end package ethernet_frame_receiver_pkg;

package body ethernet_frame_receiver_pkg is

    procedure create_ethernet_receiver
    (
        signal self      : inout ethernet_receiver_record;
        enet_rx_ddio     : in ethernet_rx_ddio_data_output_group;
        signal ram_write : out ram_write_control_record
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

            if self.crc_counter > 0 then
                self.crc_counter <= self.crc_counter - 1;
                self.crc32 <= self.crc32(23 downto 0) & x"ff";
                write_data_to_ram(ram_write, self.receiver_ram_address, self.crc32(31 downto 24));
                self.receiver_ram_address <= self.receiver_ram_address + 1;
            end if;
        end if;
    ------------------------------
        if self.rx_is_active then
            if self.receiver_ram_address < 2**10-1 then
                self.receiver_ram_address <= self.receiver_ram_address + 1;
                if self.frame_detected then
                    write_data_to_ram(ram_write, self.receiver_ram_address, inverted_enet_byte);
                else
                    write_data_to_ram(ram_write, self.receiver_ram_address, enet_byte);
                end if;
            end if;
        end if;
        
    end create_ethernet_receiver;

------------------------------------------------------------------------
        procedure transmit_byte
        (
            signal ddio_hi, ddio_lo : out std_logic_vector(4 downto 0);
            byte : in std_logic_vector(7 downto 0)
        ) is
        begin
            ddio_hi <= '1' & byte(7 downto 4);
            ddio_lo <= '1' & byte(3 downto 0);
            
        end transmit_byte;

        procedure idle_transmitter
        (
            signal ddio_hi, ddio_lo : out std_logic_vector(4 downto 0)
        ) is
        begin
            ddio_hi <= '0' & x"0";
            ddio_lo <= '0' & x"0";
            
        end idle_transmitter;

end package body ethernet_frame_receiver_pkg;
