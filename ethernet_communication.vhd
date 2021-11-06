library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_communication_pkg.all;
    use work.ethernet_pkg.all;
    use work.network_protocol_header_pkg.all;
    use work.ethernet_frame_ram_pkg.all;
    use work.ethernet_frame_ram_read_pkg.all; 

entity ethernet_communication is
    port (
        ethernet_communication_clocks     : in  ethernet_clock_group;
        ethernet_communication_FPGA_in    : in  ethernet_communication_FPGA_input_group;
        ethernet_communication_FPGA_out   : out ethernet_communication_FPGA_output_group;
        ethernet_communication_FPGA_inout : inout ethernet_communication_FPGA_inout_record;
        ethernet_communication_data_in    : in  ethernet_communication_data_input_group;
        ethernet_communication_data_out   : out ethernet_communication_data_output_group
    );
end entity ethernet_communication;

architecture rtl of ethernet_communication is

    alias clock is ethernet_communication_clocks.core_clock; 
    
    signal ethernet_FPGA_in    : ethernet_FPGA_input_group;
    signal ethernet_FPGA_out   : ethernet_FPGA_output_group;
    signal ethernet_FPGA_inout : ethernet_FPGA_inout_record;
    signal ethernet_data_in    : ethernet_data_input_group;
    signal ethernet_data_out   : ethernet_data_output_group; 

------------------------------------------------------------------------
    signal ethernet_protocol_clocks   : network_protocol_clock_group;
    signal ethernet_protocol_data_in  : network_protocol_data_input_group;
    signal ethernet_protocol_data_out : network_protocol_data_output_group;

------------------------------------------------------------------------
    signal ethernet_frame_ram_clocks   : ethernet_frame_ram_clock_group;
    signal ethernet_frame_receiver_ram_data_in  : ethernet_frame_ram_data_input_group;
    signal ethernet_frame_receiver_ram_data_out : ethernet_frame_ram_data_output_group; 

    signal receiver_ram_read_control_port : ram_read_control_group; 

    signal ethernet_frame_transmit_ram_clocks   : ethernet_frame_ram_clock_group;
    signal ethernet_frame_transmitter_ram_data_in  : ethernet_frame_ram_data_input_group;
    signal ethernet_frame_transmitter_ram_data_out : ethernet_frame_ram_data_output_group; 

------------------------------------------------------------------------ 
begin

------------------------------------------------------------------------ 
------------------------------------------------------------------------ 
    ethernet_communication_data_out <= ( ethernet_data_out          => ethernet_data_out          ,
                                         ethernet_protocol_data_out => ethernet_protocol_data_out ,
                                         frame_ram_data_out         => ethernet_frame_receiver_ram_data_out.ram_read_port_data_out); 

------------------------------------------------------------------------
------------------------------------------------------------------------
    ram_read_bus : process(ethernet_communication_data_in.receiver_ram_read_control_port, ethernet_protocol_data_out.frame_ram_read_control) 
    begin

        receiver_ram_read_control_port <= ethernet_communication_data_in.receiver_ram_read_control_port +
                                       ethernet_protocol_data_out.frame_ram_read_control;
    end process ram_read_bus;	

------------------------------------------------------------------------
------------------------------------------------------------------------ 
    ethernet_frame_receiver_ram_data_in <= (ram_write_control_port => ethernet_data_out.ram_write_control_port ,
                                           ram_read_control_port   => receiver_ram_read_control_port); 

    ethernet_frame_ram_clocks <= (read_clock  => ethernet_communication_clocks.core_clock ,
                                  write_clock => ethernet_communication_clocks.rx_ddr_clocks.rx_ddr_clock);

    u_ethernet_receiver_ram : entity work.ethernet_frame_ram(arch_cl10_ethernet_frame_ram)
    port map( ethernet_frame_ram_clocks           ,
              ethernet_frame_receiver_ram_data_in ,
              ethernet_frame_receiver_ram_data_out);

------------------------------------------------------------------------ 
    ethernet_frame_transmit_ram_clocks <= (read_clock => ethernet_communication_clocks.rx_ddr_clocks.rx_ddr_clock,
                                          write_clock => ethernet_communication_clocks.core_clock);

    u_ethernet_transmitter_ram : entity work.ethernet_frame_ram(arch_cl10_ethernet_frame_transmit)
    port map( ethernet_frame_transmit_ram_clocks     ,
              ethernet_frame_transmitter_ram_data_in ,
              ethernet_frame_transmitter_ram_data_out);

------------------------------------------------------------------------ 
------------------------------------------------------------------------ 
    ethernet_protocol_clocks <= (clock => ethernet_communication_clocks.core_clock);

    ethernet_protocol_data_in <= (
                                     frame_ram_output => ethernet_frame_receiver_ram_data_out.ram_read_port_data_out,
                                     protocol_control => ( 
                                                             protocol_processing_is_requested => ethernet_data_out.frame_is_received,
                                                             protocol_start_address           => 0
                                                         )
                                 ); 

    u_ethernet_protocol : entity work.network_protocol(arch_ethernet_protocol)
    port map( ethernet_protocol_clocks ,
    	  ethernet_protocol_data_in    ,
    	  ethernet_protocol_data_out);

------------------------------------------------------------------------ 
------------------------------------------------------------------------ 
    ethernet_data_in <= (
                            mdio_driver_data_in => ethernet_communication_data_in.ethernet_data_in.mdio_driver_data_in
                        );

    u_ethernet : ethernet
    port map( ethernet_communication_clocks                         ,
              ethernet_communication_FPGA_in.ethernet_FPGA_in       ,
              ethernet_communication_FPGA_out.ethernet_FPGA_out     ,
              ethernet_communication_FPGA_inout.ethernet_FPGA_inout ,
              ethernet_data_in                                      ,
              ethernet_data_out);

------------------------------------------------------------------------ 
end rtl;
