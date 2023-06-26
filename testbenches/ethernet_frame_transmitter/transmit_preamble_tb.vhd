LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.ethernet_frame_ram_read_pkg.all;

entity transmit_preamble_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of transmit_preamble_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal preamble_counter : natural := 0;
    signal output : std_logic_vector(7 downto 0);
    type std8_array is array (natural range <>) of std_logic_vector(7 downto 0);
    signal test_shift_register : std8_array(7 downto 0);

    constant c_example_frame : std8_array :=(x"00",x"11",x"22",x"33",x"44",x"55",x"c8",x"7f",x"54",x"54",x"57",x"cd",x"90",x"00",x"48",x"65",x"6c",x"6c",x"6f",x"2c",x"20",x"57",x"6f",x"72",x"6c",x"64",x"21",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"c9",x"92",x"2a",x"86");
    signal example_frame : std8_array(0 to c_example_frame'length-1) := (others => (others => '0'));

    constant sof : std8_array(test_shift_register'range) := (0 => x"ab", others => x"aa");
    signal preamble_detected : boolean := false;

    signal ram_read_control_port : ram_read_control_record := init_ram_read_port;
    signal ram_read_output : ram_read_output_record := init_ram_read_output;

    signal ram_address : natural := 0;
    signal address_counter : natural := 0;

    signal frame_detected : boolean := false;


begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(preamble_detected);
        check(frame_detected, "frame was not detected");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------
------------------------------------------------------------------------
    transmit_ram : process(simulator_clock)
        alias self is ram_read_output;
    begin
        if rising_edge(simulator_clock) then
            init_ram_read_output_port(self);
            if ram_read_control_port.read_is_enabled_when_1 = '1' then
                self.ram_is_ready  <= true;
                self.byte_address  <= ram_read_control_port.address;
                self.byte_from_ram <= c_example_frame(to_integer(unsigned(ram_read_control_port.address)));
            end if;

        end if; --rising_edge
    end process transmit_ram;	
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            if preamble_counter > 0 then
                preamble_counter <= preamble_counter - 1;
            end if;

            if preamble_counter > 1 then
                output <= x"aa";
            end if;

            if preamble_counter = 1 then
                output <= x"ab";
            end if;

            init_ram_read(ram_read_control_port);
            if preamble_counter = 2 then
                read_data_from_ram(ram_read_control_port, ram_address);
                ram_address <= ram_address + 1;
                address_counter <= c_example_frame'high;
            end if;

            if address_counter > 0 then
                address_counter <= address_counter - 1;
                ram_address <= ram_address + 1;
                read_data_from_ram(ram_read_control_port, ram_address);
            end if;

            if ram_data_is_ready(ram_read_output) then
                output <= get_ram_data(ram_read_output);
            end if;

            case simulation_counter is
                WHEN 7 => preamble_counter <= 8;
                when others => --do nothing
            end case;

            test_shift_register <= test_shift_register(test_shift_register'left  -1 downto 0) & output;
            example_frame <= example_frame(1 to example_frame'right) & output;
            if test_shift_register = sof then
                preamble_detected <= true;
            end if;

            if example_frame = c_example_frame then
                frame_detected <= true;
            end if;


        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
------------------------------------------------------------------------
end vunit_simulation;
