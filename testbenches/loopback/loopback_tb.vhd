LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.fifo_pkg.all;
    use work.transmit_test_pkg.bytearray;
    use work.transmit_test_pkg.c_example_frame;

entity loopback_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of loopback_tb is

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

    signal fill_counter : natural range 0 to RAM_DEPTH-1 := 0;
    signal fifo_was_filled : boolean := false;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        if run("fifo_was_filled") then
            check(fifo_was_filled, "fifo was not filled");
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

            if simulation_counter = 10 then
                fill_counter <= c_example_frame'high;
            end if;
            if fill_counter > 0 then
                fill_counter <= fill_counter - 1;
                write_data_to_fifo(fifo_write_in, c_example_frame(c_example_frame'high - fill_counter));
            end if;

            if get_number_of_words_in_fifo(fifo_read_out) = c_example_frame'high then
                fifo_was_filled <= true;
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
------------------------------------------------------------------------
    u_fifo : entity work.fifo
    port map(simulator_clock, reset, fifo_read_in, fifo_read_out, fifo_write_in, fifo_write_out);
------------------------------------------------------------------------
end vunit_simulation;
