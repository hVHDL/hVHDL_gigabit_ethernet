LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.ethernet_frame_ram_read_pkg.all;
    use work.ethernet_frame_ram_write_pkg.all;

entity dpram is
    port (
        clk1 : in std_logic	;
        read_port_control : in ram_read_control_record;
        read_port_out     : out ram_read_output_group;

        clk2 : in std_logic	;
        ram_write_port : in ram_write_control_record
    );
end entity dpram;


architecture test of dpram is

    type bytearray is array (integer range 0 to 2**10-1) of std_logic_vector(7 downto 0);
    signal ram_data : bytearray := (others => (others => '0'));

    function int ( std_vector : std_logic_vector ) return natural is
    begin
        return to_integer(unsigned(std_vector));
    end int;

begin

    read_dp_ram : process(clk1)
        
    begin
        --------------------------------------------------
        if rising_edge(clk1) then
            read_port_out.ram_is_ready <= false;
            if read_port_control.read_is_enabled_when_1 = '1' then
                read_port_out.ram_is_ready  <= true;
                read_port_out.byte_address  <= read_port_control.address;
                read_port_out.byte_from_ram <= ram_data(int(read_port_control.address));
            end if;
        end if; --rising_edge

    end process read_dp_ram;	

    write_dp_ram : process(clk2)
        
    begin
        if rising_edge(clk2) then
            if ram_write_port.write_enabled_when_1 = '1' then
                ram_data(int(ram_write_port.address)) <= ram_write_port.byte_to_write;
            end if;
        end if; --rising_edge
    end process write_dp_ram;	

end test;
