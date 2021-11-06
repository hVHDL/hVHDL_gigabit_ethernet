library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.PCK_CRC32_D8.all;
    use work.ethernet_frame_ram_read_pkg.all; 

package ethernet_frame_transmit_controller_pkg is
------------------------------------------------------------------------
    type list_of_frame_transmitter_states is (idle, transmit_preable, transmit_data, transmit_fcs); 

    type frame_transmitter_record is record
        frame_transmitter_state  : list_of_frame_transmitter_states;
        fcs_shift_register       : std_logic_vector(31 downto 0);
        byte_counter             : natural range 0 to 2**12-1;
        frame_length             : natural range 0 to 2**12-1;
        byte                     : std_logic_vector(7 downto 0);
        frame_transmit_requested : boolean;
        write_data_to_fifo       : boolean;
        ram_shift_register       : std_logic_vector(31 downto 0);
        ram_read_controller      : ram_reader;
        ram_output_port          : ram_read_output_group;
    end record;

    constant init_transmit_controller : frame_transmitter_record := 
    (
        frame_transmitter_state  => idle            ,
        fcs_shift_register       => (others => '1') ,
        byte_counter             => 0               ,
        frame_length             => 0               ,
        byte                     => x"00"           ,
        frame_transmit_requested => false           ,
        write_data_to_fifo       => false           ,
        ram_shift_register       => (others => '0') ,
        ram_read_controller      => ram_reader_init ,
        ram_output_port          => ram_read_output_init
    );

------------------------------------------------------------------------
    procedure create_transmit_controller (
        signal transmit_controller : inout frame_transmitter_record);
------------------------------------------------------------------------
    procedure request_ethernet_frame_transmission (
        signal transmit_controller : inout frame_transmitter_record;
        number_of_bytes_to_transmit : natural range 0 to 2047);
------------------------------------------------------------------------
    function frame_transmit_is_requested ( transmit_controller : frame_transmitter_record)
        return boolean;
------------------------------------------------------------------------
end package ethernet_frame_transmit_controller_pkg;

package body ethernet_frame_transmit_controller_pkg is

--------------------------------------------------
    function invert_bit_order
    (
        std_vector : std_logic_vector(31 downto 0)
    )
    return std_logic_vector 
    is
        variable reordered_vector : std_logic_vector(31 downto 0);
    begin
        for i in reordered_vector'range loop
            reordered_vector(i) := std_vector(std_vector'left - i);
        end loop;
        return reordered_vector;
    end invert_bit_order;

--------------------------------------------------
    function reverse_bit_order
    (
        std_vector : std_logic_vector 
    )
    return std_logic_vector 
    is
        variable reordered_vector : std_logic_vector(7 downto 0);
    begin
        for i in reordered_vector'range loop
            reordered_vector(i) := std_vector(std_vector'left - i);
        end loop;
        return reordered_vector;
    end reverse_bit_order;

--------------------------------------------------
------------------------------------------------------------------------
    procedure create_transmit_controller
    (
        signal transmit_controller : inout frame_transmitter_record
    ) is
        alias frame_transmitter_state  is  transmit_controller.frame_transmitter_state;
        alias fcs_shift_register       is  transmit_controller.fcs_shift_register;
        alias byte_counter             is  transmit_controller.byte_counter;
        alias frame_length             is  transmit_controller.frame_length;
        alias byte                     is  transmit_controller.byte;
        alias frame_transmit_requested is  transmit_controller.frame_transmit_requested;
        alias write_data_to_fifo       is  transmit_controller.write_data_to_fifo;

        variable data_to_ethernet : std_logic_vector(7 downto 0);
    begin
        frame_transmit_requested <= false;
        write_data_to_fifo <= false;
        CASE frame_transmitter_state is
            WHEN idle =>
                byte_counter <= 0;
                fcs_shift_register <= (others => '1');
                byte <= x"00";
            WHEN transmit_preable =>

                write_data_to_fifo <= true;

                fcs_shift_register <= (others => '1');
                byte_counter <= byte_counter + 1;
                if byte_counter < 7 then
                    byte <= x"aa";
                end if;

                frame_transmitter_state <= transmit_preable;
                if byte_counter = 7 then
                    byte <= x"ab";
                    frame_transmitter_state <= transmit_data;
                    byte_counter <= 0;


                    load_ram_with_offset_to_shift_register(ram_controller                     => transmit_controller.ram_read_controller ,
                                                           start_address                      => 0                   ,
                                                           number_of_ram_addresses_to_be_read => frame_length);

                end if;
            WHEN transmit_data => 
                if ram_data_is_ready(transmit_controller.ram_output_port) then
                    write_data_to_fifo <= true;

                    data_to_ethernet := reverse_bit_order(transmit_controller.ram_shift_register(7 downto 0));


                    byte_counter <= byte_counter + 1; 
                    if byte_counter < frame_length then
                        fcs_shift_register <= nextCRC32_D8(data_to_ethernet, fcs_shift_register);
                        byte               <= data_to_ethernet;
                    end if;

                    frame_transmitter_state <= transmit_data;
                    if byte_counter = frame_length-1 then
                        frame_transmitter_state <= transmit_fcs;
                        byte_counter <= 0;
                    end if;
                end if; 

            WHEN transmit_fcs => 
                write_data_to_fifo <= true;

                byte_counter       <= byte_counter + 1;
                fcs_shift_register <= fcs_shift_register(23 downto 0) & x"ff";
                byte               <= not (fcs_shift_register(31 downto 24));

                frame_transmitter_state <= transmit_fcs;
                if byte_counter = 3 then
                    frame_transmitter_state <= idle;
                    byte_counter <= 0;
                    frame_transmit_requested <= true;
                end if;
        end CASE; 

    end create_transmit_controller;

------------------------------------------------------------------------
    procedure request_ethernet_frame_transmission
    (
        signal transmit_controller : inout frame_transmitter_record;
        number_of_bytes_to_transmit : natural range 0 to 2047
    ) is
        alias frame_transmitter_state is transmit_controller.frame_transmitter_state;
        alias frame_length            is transmit_controller.frame_length;
    begin
        frame_transmitter_state <= transmit_preable;
        frame_length <= number_of_bytes_to_transmit;
        
    end request_ethernet_frame_transmission;

------------------------------------------------------------------------
    function frame_transmit_is_requested
    (
        transmit_controller : frame_transmitter_record
    )
    return boolean
    is
    begin
        return transmit_controller.frame_transmit_requested;
    end frame_transmit_is_requested; 
------------------------------------------------------------------------
    function frame_data_is_ready
    (
        transmit_controller : frame_transmitter_record
    )
    return boolean
    is
    begin
        return transmit_controller.frame_transmit_requested;
        
    end frame_data_is_ready;

------------------------------------------------------------------------
end package body ethernet_frame_transmit_controller_pkg; 
