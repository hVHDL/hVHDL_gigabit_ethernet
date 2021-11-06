library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_frame_receiver_pkg.all;
    use work.ethernet_frame_receiver_internal_pkg.all;
    use work.ethernet_rx_ddio_pkg.all; 
    use work.ethernet_frame_ram_write_pkg.all;

entity ethernet_frame_receiver is
    port (
        ethernet_frame_receiver_clocks   : in ethernet_rx_ddr_clock_group;
        ethernet_frame_receiver_FPGA_in  : in ethernet_frame_receiver_FPGA_input_group;
        ethernet_frame_receiver_data_out : out ethernet_frame_receiver_data_output_group
    );
end entity ethernet_frame_receiver;

architecture rtl of ethernet_frame_receiver is 

    alias rx_ddr_clock is ethernet_frame_receiver_clocks.rx_ddr_clock; 

    signal ethernet_rx_ddio_data_out  : ethernet_rx_ddio_data_output_group;
    signal ethernet_rx : ethernet_receiver;

------------------------------------------------------------------------
begin

    ethernet_frame_receiver_data_out <= (
                                            ram_write_control_port       => ethernet_rx.ram_write_control_port,
                                            toggle_data_has_been_written => ethernet_rx.toggle_data_has_been_written
                                        );

------------------------------------------------------------------------
    frame_receiver : process(rx_ddr_clock) 

    begin
        if rising_edge(rx_ddr_clock) then 

            ethernet_rx.rx_shift_register <= ethernet_rx.rx_shift_register(7 downto 0) & get_byte(ethernet_rx_ddio_data_out); 
            init_ram_write(ethernet_rx.ram_write_control_port);


            ethernet_rx.toggle_data_has_been_written <= '0'; 
            if ethernet_rx_is_active(ethernet_rx_ddio_data_out) then
                capture_ethernet_frame(ethernet_rx, ethernet_rx_ddio_data_out); 

            else
                ethernet_rx.toggle_data_has_been_written <= '1'; 
                idle_ethernet_rx(ethernet_rx);

            end if; 

        end if; --rising_edge
    end process frame_receiver;	

------------------------------------------------------------------------
    u_ethernet_rx_ddio : ethernet_rx_ddio
    port map( ethernet_frame_receiver_clocks                           ,
              ethernet_frame_receiver_FPGA_in.ethernet_rx_ddio_FPGA_in ,
              ethernet_rx_ddio_data_out);

------------------------------------------------------------------------
end rtl;
