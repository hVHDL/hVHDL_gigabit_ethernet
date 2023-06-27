LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.transmit_test_pkg.c_example_frame;
    use work.ethernet_tx_pkg.all;

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

    signal fill_counter : natural := 0;
    signal fifo_was_filled : boolean := false;
    signal fill_ready : boolean := false;

    signal check_crc : std_logic_vector(31 downto 0);

    signal crc_was_detected : boolean := false;

    signal preamble_counter : natural range 0 to 7 := 0;
    signal preamble_counter_is_ready : boolean := false;

    signal tx_in : ethernet_tx_input_record;
    signal tx_out : ethernet_tx_output_record;
    signal tx_is_active : boolean := false;
    signal byte_out : std_logic_vector(7 downto 0);

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

        constant number_of_words_in_frame : natural := c_example_frame'high + 1;

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            init_ethernet_tx(tx_in);

            if simulation_counter = 10 then
                fill_counter <= number_of_words_in_frame;
            end if;
            if fill_counter > 0 then
                fill_counter <= fill_counter - 1;
                load_data_to_transmit_fifo(tx_in, c_example_frame(number_of_words_in_frame - fill_counter));
            end if;

            if fill_counter = 1 then
                request_ethernet_frame(tx_in);
            end if;
        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
------------------------------------------------------------------------
    u_ethernet_tx : entity work.ethernet_tx
    port map(simulator_clock, tx_in, tx_out, tx_is_active, byte_out);
------------------------------------------------------------------------
end vunit_simulation;
