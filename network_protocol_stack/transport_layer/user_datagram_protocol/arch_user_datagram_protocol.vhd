library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- entity network_protocol is
--     port (
--         network_protocol_clocks   : in network_protocol_clock_group;
--         network_protocol_data_in  : in network_protocol_data_input_group;
--         network_protocol_data_out : out network_protocol_data_output_group
--     );
-- end entity network_protocol;

architecture arch_user_datagram_protocol of network_protocol is

    alias clock is network_protocol_clocks.clock;
    alias udp_protocol_data_in is network_protocol_data_in;
    alias udp_protocol_data_out is network_protocol_data_out;
    alias protocol_control is udp_protocol_data_in.protocol_control; 

    signal frame_ram_read_control_port : ram_read_control_group;
    signal shift_register : std_logic_vector(31 downto 0);
    signal ram_read_controller : ram_reader;
    signal ram_offset : natural range 0 to 2**11-1;
    signal header_offset : natural range 0 to 2**11-1;

    signal frame_processing_is_ready : boolean;

begin

------------------------------------------------------------------------
    route_data_out : process(frame_ram_read_control_port, ram_offset, frame_processing_is_ready) 
    begin
        udp_protocol_data_out <= (
                                      frame_ram_read_control    => frame_ram_read_control_port ,
                                      ram_offset                => ram_offset                  ,
                                      frame_processing_is_ready => frame_processing_is_ready
                                  );

    end process route_data_out;	
------------------------------------------------------------------------

    udp_header_processor : process(clock)

        type list_of_protocol_processor_states is (wait_for_process_request, read_header);
        variable udp_protocol_state : list_of_protocol_processor_states := wait_for_process_request;
        
    begin
        if rising_edge(clock) then
            create_ram_read_controller(frame_ram_read_control_port, udp_protocol_data_in.frame_ram_output, ram_read_controller, shift_register); 

            frame_processing_is_ready <= false;
            ram_offset <= 0;
            CASE udp_protocol_state is
                WHEN wait_for_process_request =>
                    if protocol_control.protocol_processing_is_requested then
                        header_offset <= protocol_control.protocol_start_address;

                        load_ram_with_offset_to_shift_register(ram_controller                     => ram_read_controller,
                                                               start_address                      => protocol_control.protocol_start_address,
                                                               number_of_ram_addresses_to_be_read => 8);

                        udp_protocol_state := read_header;
                    end if;

                WHEN read_header => 

                    if get_ram_address(udp_protocol_data_in.frame_ram_output) = header_offset+8 then
                        frame_processing_is_ready <= true;
                        ram_offset <= header_offset;
                        udp_protocol_state := wait_for_process_request;
                    end if;

            end CASE;

        end if; --rising_edge
    end process udp_header_processor;	

end arch_user_datagram_protocol;
