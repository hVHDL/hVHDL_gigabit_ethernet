library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_frame_receiver_pkg.all;
    use work.ethernet_rx_ddio_pkg.all; 
    use work.PCK_CRC32_D8.all;
    use work.ethernet_frame_ram_write_pkg.all;

package ethernet_frame_receiver_internal_pkg is

    constant ram_max_index : integer := 2047;

    constant ethernet_fcs_checksum    : std_logic_vector(31 downto 0) := x"c704dd7b";
    constant ethernet_frame_delimiter : std_logic_vector(7 downto 0)  := x"AB";
    constant ethernet_frame_preamble  : std_logic_vector(15 downto 0) := x"AAAA";

    type list_of_frame_receiver_states is (wait_for_start_of_frame, receive_frame);

    type ethernet_receiver is record
        frame_receiver_state         : list_of_frame_receiver_states;
        rx_shift_register            : std_logic_vector(15 downto 0);
        toggle_data_has_been_written : std_logic;
        fcs_shift_register           : std_logic_vector(31 downto 0);

        ram_write_control_port : ram_write_control_group;
        ram_write_counter      : natural range 0 to ram_max_index;
    end record;

------------------------------------------------------------------------
    procedure capture_ethernet_frame (
        signal ethernet_rx : inout ethernet_receiver;
        ethernet_ddio_out : ethernet_rx_ddio_data_output_group);

------------------------------------------------------------------------
    procedure idle_ethernet_rx (
        signal ethernet_rx : inout ethernet_receiver);
------------------------------------------------------------------------
    procedure calculate_fcs (
        signal ethernet_rx : inout ethernet_receiver;
        ethernet_ddio_out : ethernet_rx_ddio_data_output_group);

end package ethernet_frame_receiver_internal_pkg;


package body ethernet_frame_receiver_internal_pkg is

------------------------------------------------------------------------
    procedure capture_ethernet_frame
    (
        signal ethernet_rx : inout ethernet_receiver;
        ethernet_ddio_out : ethernet_rx_ddio_data_output_group
    ) is
        alias frame_receiver_state         is  ethernet_rx.frame_receiver_state         ;
        alias rx_shift_register            is  ethernet_rx.rx_shift_register            ;
        alias ram_write_control_port       is  ethernet_rx.ram_write_control_port       ;
        alias toggle_data_has_been_written is  ethernet_rx.toggle_data_has_been_written ;
        alias ram_write_counter            is  ethernet_rx.ram_write_counter            ;
        alias fcs_shift_register           is  ethernet_rx.fcs_shift_register           ;

    begin

        CASE frame_receiver_state is
            WHEN wait_for_start_of_frame =>
                if rx_shift_register = ethernet_frame_preamble and get_byte(ethernet_ddio_out) = ethernet_frame_delimiter  then
                    frame_receiver_state <= receive_frame;
                end if;

            WHEN receive_frame =>

                ram_write_counter <= ram_write_counter + 1; 
                write_data_to_ram(ram_write_control_port, ram_write_counter,  get_byte_with_inverted_bit_order(ethernet_ddio_out)); 
                calculate_fcs(ethernet_rx, ethernet_ddio_out); 

        end CASE;
    end capture_ethernet_frame;

------------------------------------------------------------------------
    procedure calculate_fcs
    (
        signal ethernet_rx : inout ethernet_receiver;
        ethernet_ddio_out : ethernet_rx_ddio_data_output_group
    ) is
        alias fcs_shift_register is ethernet_rx.fcs_shift_register;
    begin
        if fcs_shift_register /= ethernet_fcs_checksum then
            fcs_shift_register <= nextCRC32_D8(get_byte(ethernet_ddio_out), fcs_shift_register);
        end if;
        
    end calculate_fcs;

------------------------------------------------------------------------
    procedure idle_ethernet_rx
    (
        signal ethernet_rx : inout ethernet_receiver
        
    ) is
        alias frame_receiver_state         is ethernet_rx.frame_receiver_state         ;
        alias rx_shift_register            is ethernet_rx.rx_shift_register            ;
        alias ram_write_control_port       is ethernet_rx.ram_write_control_port       ;
        alias toggle_data_has_been_written is ethernet_rx.toggle_data_has_been_written ;
        alias ram_write_counter            is ethernet_rx.ram_write_counter            ;
        alias fcs_shift_register           is ethernet_rx.fcs_shift_register           ;
    begin
        if ram_write_counter > 0 and ram_write_counter < 256 then
            ram_write_counter <= ram_write_counter + 1;

            if ethernet_rx.fcs_shift_register = ethernet_fcs_checksum then
                write_data_to_ram(ram_write_control_port, ram_write_counter,  x"EE");
            else
                write_data_to_ram(ram_write_control_port, ram_write_counter,  x"dd");
            end if;
        else
            ram_write_counter <= 0;
            fcs_shift_register <= (others => '1');

            frame_receiver_state <= wait_for_start_of_frame;
        end if; 
    end idle_ethernet_rx; 

end package body ethernet_frame_receiver_internal_pkg;
