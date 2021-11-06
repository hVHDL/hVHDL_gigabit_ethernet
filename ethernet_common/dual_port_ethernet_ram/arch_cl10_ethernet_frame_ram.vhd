-- library ieee;
--     use ieee.std_logic_1164.all;
--     use ieee.numeric_std.all;
--
-- library work;
--     use work.ethernet_frame_ram_pkg.all;
--
-- entity ethernet_frame_ram is
--     port (
--         ethernet_frame_ram_clocks   : in ethernet_frame_ram_clock_group;
--         ethernet_frame_ram_data_in  : in ethernet_frame_ram_data_input_group;
--         ethernet_frame_ram_data_out : out ethernet_frame_ram_data_output_group
--     );
-- end entity ethernet_frame_ram;

architecture arch_cl10_ethernet_frame_ram of ethernet_frame_ram is

    alias ram_write_control_port is ethernet_frame_ram_data_in.ram_write_control_port;
    alias ram_read_control_port is ethernet_frame_ram_data_in.ram_read_control_port;
    
    component dual_port_ethernet_ram IS
	PORT
	(
		data      : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdaddress : IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		rdclock   : IN STD_LOGIC ;
		rden      : IN STD_LOGIC                       := '1';
		wraddress : IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		wrclock   : IN STD_LOGIC                       := '1';
		wren      : IN STD_LOGIC                       := '0';
		q         : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
    end component dual_port_ethernet_ram;

    signal q         : STD_LOGIC_VECTOR (7 DOWNTO 0);

    signal data_is_ready_to_be_read : boolean := false;
    signal data_is_ready_to_be_read_buffer : boolean := false;
    signal address_buffer : std_logic_vector(10*2+1 downto 0);

begin

    ethernet_frame_ram_data_out <= (ram_read_port_data_out =>(ram_is_ready  => data_is_ready_to_be_read_buffer                                   ,
                                                              byte_address  => address_buffer(address_buffer'left downto address_buffer'left-10) ,
                                                              byte_from_ram => q)
                                  );

    data_is_ready_pipeline : process(ethernet_frame_ram_clocks.read_clock)
        
    begin
        if rising_edge(ethernet_frame_ram_clocks.read_clock) then

            data_is_ready_to_be_read <= false;
            if ram_read_control_port.read_is_enabled_when_1 = '1' then
                data_is_ready_to_be_read <= true;
            end if;
            address_buffer <= address_buffer(10 downto 0) & ram_read_control_port.address;
            data_is_ready_to_be_read_buffer <= data_is_ready_to_be_read;

        end if; --rising_edge
    end process data_is_ready_pipeline;	

    u_dual_port_ethernet_ram : dual_port_ethernet_ram
    port map(
                wrclock   => ethernet_frame_ram_clocks.write_clock,
                data      => ram_write_control_port.byte_to_write,
                wraddress => ram_write_control_port.address,
                wren      => ram_write_control_port.write_enabled_when_1,

                rdclock   => ethernet_frame_ram_clocks.read_clock,
                rdaddress => ram_read_control_port.address,
                rden      => ram_read_control_port.read_is_enabled_when_1,
                q         => q);

end arch_cl10_ethernet_frame_ram;
