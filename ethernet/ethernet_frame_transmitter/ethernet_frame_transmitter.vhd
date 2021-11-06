library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_frame_transmitter_pkg.all;
    use work.ethernet_frame_transmit_controller_pkg.all;
    use work.ethernet_tx_ddio_pkg.all;

    use work.ethernet_frame_ram_pkg.all;
    use work.ethernet_frame_ram_read_pkg.all; 

    use work.ethernet_transmit_fifo_pkg.all;

entity ethernet_frame_transmitter is
    port (
        tx_ddr_clocks                       : in ethernet_tx_ddr_clock_group;
        ethernet_frame_transmitter_FPGA_out : out ethernet_frame_transmitter_FPGA_output_group;
        ethernet_frame_transmitter_data_in  : in ethernet_frame_transmitter_data_input_group;
        ethernet_frame_transmitter_data_out : out ethernet_frame_transmitter_data_output_group
    );
end entity ethernet_frame_transmitter;

architecture rtl of ethernet_frame_transmitter is 
    
    signal ethernet_tx_ddio_clocks   : ethernet_tx_ddr_clock_group;
    signal ethernet_tx_ddio_FPGA_out : ethernet_tx_ddio_FPGA_output_group;
    signal ethernet_tx_ddio_data_in  : ethernet_tx_ddio_data_input_group;
    
    constant counter_value_at_100kHz : natural := 12500;
    signal counter_for_100kHz : natural range 0 to 2**16-1 := counter_value_at_100kHz;

    constant counter_value_at_1600ms : natural := 33e3/2;
    signal counter_for_1600ms : natural range 0 to 2**16-1 := counter_value_at_1600ms;


    signal frame_transmit_controller : frame_transmitter_record := init_transmit_controller;

    signal testicounter : natural range 0 to 255 := 60;

    signal fifo_data_input  : fifo_input_control_group;
    signal fifo_data_output : fifo_output_control_group;

    signal ddr_control_state : list_of_ddr_control_states;

    signal ethernet_frame_ram_clocks   : ethernet_frame_ram_clock_group;
    signal ethernet_frame_transmitter_ram_data_in  : ethernet_frame_ram_data_input_group;
    signal ethernet_frame_transmitter_ram_data_out : ethernet_frame_ram_data_output_group; 

    signal transmitter_ram_read_control_port : ram_read_control_group; 


------------------------------------------------------------------------
begin

    -- ethernet_frame_transmitter_ram_data_in <= (ram_write_control_port => ethernet_data_out.ram_write_control_port ,
    --                                            ram_read_control_port  => transmitter_ram_read_control_port);

------------------------------------------------------------------------
    ethernet_frame_transmitter_ram_data_in.ram_read_control_port  <= transmitter_ram_read_control_port;

    ethernet_frame_ram_clocks <= (read_clock  => tx_ddr_clocks.tx_ddr_clock ,
                                  write_clock => tx_ddr_clocks.tx_ddr_clock);

    u_ethernet_transmitter_ram : entity work.ethernet_frame_ram(arch_cl10_ethernet_frame_transmit)
    port map( ethernet_frame_ram_clocks              ,
              ethernet_frame_transmitter_ram_data_in ,
              ethernet_frame_transmitter_ram_data_out); 

------------------------------------------------------------------------
    u_tx_fifo : tx_fifo
	PORT map
	(
		clock        => tx_ddr_clocks.tx_ddr_clock    ,
		data         => fifo_data_input.data          ,
		rdreq        => fifo_data_input.rdreq         ,
		wrreq        => fifo_data_input.wrreq         ,
		almost_empty => fifo_data_output.almost_empty ,
		empty        => fifo_data_output.empty        ,
		q            => fifo_data_output.q            
	);

------------------------------------------------------------------------ 
    frame_transmitter : process(tx_ddr_clocks.tx_ddr_clock) 
        
    begin
        if rising_edge(tx_ddr_clocks.tx_ddr_clock) then

        --------------------------------------------------
            if counter_for_100kHz > 0 then
                counter_for_100kHz <= counter_for_100kHz - 1;
            else
                counter_for_100kHz <= counter_value_at_100kHz;

                if counter_for_1600ms > 0 then
                    counter_for_1600ms <= counter_for_1600ms - 1;
                else
                    counter_for_1600ms <= counter_value_at_1600ms;
                    testicounter <= testicounter + 1;
                    if testicounter > 101 then
                        testicounter <= 92;
                    end if;
                    request_ethernet_frame_transmission(frame_transmit_controller, testicounter);
                end if;
            end if; 

        --------------------------------------------------
            init_ethernet_tx_ddio(ethernet_tx_ddio_data_in);
            init_fifo(fifo_data_input);
            
            create_ram_read_controller(transmitter_ram_read_control_port                               ,
                                        ethernet_frame_transmitter_ram_data_out.ram_read_port_data_out ,
                                        frame_transmit_controller.ram_read_controller                  ,
                                        frame_transmit_controller.ram_shift_register); 

            create_transmit_controller(frame_transmit_controller);
            frame_transmit_controller.ram_output_port <= ethernet_frame_transmitter_ram_data_out.ram_read_port_data_out;

            if frame_transmit_controller.write_data_to_fifo then
                write_data_to_fifo(fifo_data_input, frame_transmit_controller.byte);
            end if; 

            CASE ddr_control_state is
                WHEN idle =>
                    ddr_control_state <= idle;
                    if frame_transmit_is_requested(frame_transmit_controller) then
                        ddr_control_state <= transmit;
                        load_data_from_fifo(fifo_data_input);
                    end if;
                WHEN transmit =>
                    ddr_control_state <= transmit;
                    if fifo_data_output.almost_empty /= '1' then
                        load_data_from_fifo(fifo_data_input);
                        transmit_8_bits_of_data(ethernet_tx_ddio_data_in, get_data_from_fifo(fifo_data_output));
                    else
                        transmit_8_bits_of_data(ethernet_tx_ddio_data_in, get_data_from_fifo(fifo_data_output));
                        ddr_control_state <= idle;
                    end if;

            end CASE; 
        end if; --rising_edge
    end process frame_transmitter;	

------------------------------------------------------------------------
    u_ethernet_tx_ddio_pkg : ethernet_tx_ddio
    port map( tx_ddr_clocks                                                 ,
              ethernet_frame_transmitter_FPGA_out.ethernet_tx_ddio_FPGA_out ,
              ethernet_tx_ddio_data_in);

------------------------------------------------------------------------
end rtl;
