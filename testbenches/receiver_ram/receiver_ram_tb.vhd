LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.ethernet_frame_ram_read_pkg.all;
    use work.ethernet_frame_ram_write_pkg.all;

entity dpram is
    port (
        clk1 : in std_logic	;
        clk2 : in std_logic	;
        read_port_control : in ram_read_control_record
    );
end entity dpram;


architecture test of dpram is


begin


end test;
------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.ethernet_frame_ram_read_pkg.all;

entity receiver_ram_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of receiver_ram_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 50;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal ram_read_control_port : ram_read_control_group := init_ram_read_port;
    signal ram_read_out_port : ram_read_output_group := ram_read_output_init;

    signal ram_reader : ram_reader_record := init_ram_reader;
    signal shift_register : std_logic_vector(31 downto 0) := (others => '0');

    type std8_array is array (integer range <>) of std_logic_vector(7 downto 0);
    constant test_frame : std8_array := (x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"c4", x"65", x"16", x"ae", x"5e", x"4f", x"08", x"00", x"45", x"00", x"00", x"4e", x"3a", x"df", x"00", x"00", x"80", x"11", x"00", x"00", x"a9", x"fe", x"52", x"ba", x"a9", x"fe", x"ff", x"ff", x"00", x"89", x"00", x"89", x"00", x"3a", x"5c", x"09", x"8c", x"3b", x"01", x"10", x"00", x"01", x"00", x"00", x"00", x"00", x"00", x"00", x"20", x"45", x"45", x"45", x"42", x"45", x"4f", x"45", x"47", x"45", x"50", x"46", x"44", x"46", x"44", x"43", x"41", x"43", x"41", x"43", x"41", x"43", x"41", x"43", x"41", x"43", x"41", x"43", x"41", x"43", x"41", x"42", x"4f", x"00", x"00", x"20", x"00", x"01");
    signal test_frame_s : std8_array(0 to test_frame'length-1) := test_frame;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_ram_reader(ram_reader, ram_read_control_port, ram_read_out_port, shift_register);

            case simulation_counter is 
                WHEN 15 => load_ram_with_offset_to_shift_register(ram_reader, 6, 4);
                when others => --do nothing
            end case;

            if ram_is_buffered_to_shift_register(ram_reader) then
                check(shift_register = x"c46516ae");
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    ram_test : process(simulator_clock)

        function int ( std : std_logic_vector ) return natural is
        begin
            return to_integer(unsigned(std));
        end int;
        
    begin
        if rising_edge(simulator_clock) then
            ram_read_out_port.ram_is_ready <= false;
            if ram_read_control_port.read_is_enabled_when_1 = '1' then
                ram_read_out_port.ram_is_ready <= true;
                ram_read_out_port.byte_address <= ram_read_control_port.address;
                ram_read_out_port.byte_from_ram <= test_frame_s(int(ram_read_control_port.address));
            end if;

        end if; --rising_edge
    end process ram_test;	
end vunit_simulation;
