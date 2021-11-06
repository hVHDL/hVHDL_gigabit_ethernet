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

architecture arch_internet_protocol of network_protocol is

    alias clock is network_protocol_clocks.clock;
    alias internet_protocol_data_in is network_protocol_data_in;
    alias internet_protocol_data_out is network_protocol_data_out;
    alias protocol_control is internet_protocol_data_in.protocol_control; 

    signal frame_ram_read_control_port : ram_read_control_group;
    signal shift_register : std_logic_vector(31 downto 0);
    signal ram_read_controller : ram_reader;
    signal ram_offset : natural range 0 to 2**11-1;
    signal header_offset : natural range 0 to 2**11-1;

------------------------------------------------------------------------ 
    signal udp_protocol_clocks   : network_protocol_clock_group;
    signal udp_protocol_data_in  : network_protocol_data_input_group;
    signal udp_protocol_data_out : network_protocol_data_output_group;
    signal udp_protocol_control  : protocol_control_record; 
    signal frame_processing_is_ready : boolean;

    signal ip_header_offset_in_bytes : natural range 0 to 2**4-1;

begin

------------------------------------------------------------------------
    route_data_out : process(frame_ram_read_control_port, ram_offset, udp_protocol_data_out, frame_processing_is_ready) 
    begin
        internet_protocol_data_out <= (
                                          frame_ram_read_control => frame_ram_read_control_port + udp_protocol_data_out.frame_ram_read_control ,
                                          ram_offset => udp_protocol_data_out.ram_offset + ram_offset                                          ,
                                          frame_processing_is_ready => frame_processing_is_ready or udp_protocol_data_out.frame_processing_is_ready
                                      );

    end process route_data_out;	
------------------------------------------------------------------------

    ip_header_processor : process(clock)

        type list_of_protocol_processor_states is (wait_for_process_request, read_header);
        variable internet_protocol_state : list_of_protocol_processor_states := wait_for_process_request;
        
    begin
        if rising_edge(clock) then
            create_ram_read_controller(frame_ram_read_control_port, internet_protocol_data_in.frame_ram_output, ram_read_controller, shift_register); 
            init_protocol_control(udp_protocol_control);

            frame_processing_is_ready <= false;
            ram_offset <= 0; 
            CASE internet_protocol_state is
                WHEN wait_for_process_request =>
                    if protocol_control.protocol_processing_is_requested then
                        load_ram_with_offset_to_shift_register(ram_controller                     => ram_read_controller,
                                                               start_address                      => protocol_control.protocol_start_address,
                                                               number_of_ram_addresses_to_be_read => 10);

                        header_offset <= protocol_control.protocol_start_address;
                        internet_protocol_state := read_header;
                    end if;

                WHEN read_header =>

                    if ram_data_is_ready(internet_protocol_data_in.frame_ram_output) then
                        if get_ram_address(internet_protocol_data_in.frame_ram_output) = header_offset+1 then
                            ip_header_offset_in_bytes <= to_integer(unsigned(shift_register(3 downto 0)))*4;
                        end if;

                        if get_ram_address(internet_protocol_data_in.frame_ram_output) = header_offset+10 then
                            if shift_register(7 downto 0) = x"11" then
                                request_protocol_processing(udp_protocol_control, header_offset + 20);
                            else
                                ram_offset <= header_offset;
                                frame_processing_is_ready <= true; 
                            end if;
                            internet_protocol_state := wait_for_process_request;
                        end if;
                    end if;
            end CASE;

        end if; --rising_edge
    end process ip_header_processor;	

------------------------------------------------------------------------ 
    udp_protocol_clocks <= (clock => clock);

    udp_protocol_data_in <= (frame_ram_output => internet_protocol_data_in.frame_ram_output, 
                                 protocol_control => udp_protocol_control);

    u_udp_protocol : entity work.network_protocol(arch_user_datagram_protocol)
    port map( udp_protocol_clocks  ,
              udp_protocol_data_in ,
              udp_protocol_data_out); 

------------------------------------------------------------------------ 
end arch_internet_protocol;
