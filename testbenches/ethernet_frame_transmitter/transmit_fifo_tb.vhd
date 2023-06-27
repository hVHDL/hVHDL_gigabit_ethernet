------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.fifo_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity transmit_fifo_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of transmit_fifo_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal fifo_read_in   : fifo_read_input_record;
    signal fifo_read_out  : fifo_read_output_record;
    signal fifo_write_in  : fifo_write_input_record;
    signal fifo_write_out : fifo_write_output_record;
    signal reset : std_logic := '1';

    signal number_of_fifo_words : natural := 0;

    type std8_array is array (integer range 0 to 7) of std_logic_vector(7 downto 0);
    constant check_values : std8_array := (0 => x"ab", 1 => x"cd", 2 => x"ef", others => x"00"); 

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        if run("3_words_were_read_from_fifo") then
            check(number_of_fifo_words = 3, "expected 3, got " & integer'image(number_of_fifo_words));
        end if;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            reset <= '0';
            init_fifo_read(fifo_read_in);
            init_fifo_write(fifo_write_in);

            CASE simulation_counter is
                WHEN 10 => write_data_to_fifo(fifo_write_in, check_values(0));
                WHEN 11 => write_data_to_fifo(fifo_write_in, check_values(1));
                WHEN 16 => write_data_to_fifo(fifo_write_in, check_values(2));
                WHEN others => --do nothing
            end CASE;

            if simulation_counter > 50 then
                if fifo_can_be_read(fifo_read_out) then
                    request_data_from_fifo(fifo_read_in);
                end if;
            end if;

            if fifo_read_is_ready(fifo_read_out) then
                number_of_fifo_words <= number_of_fifo_words + 1;
                check(check_values(number_of_fifo_words) = get_data_from_fifo(fifo_read_out));
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_fifo : entity work.fifo
    port map(simulator_clock, reset, fifo_read_in, fifo_read_out, fifo_write_in, fifo_write_out);
------------------------------------------------------------------------
end vunit_simulation;
