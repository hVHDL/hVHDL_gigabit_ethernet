LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.mdio_driver_internal_pkg.all;

entity mdio_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of mdio_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    --------------------------------
    signal shift_register : std_logic_vector(15 downto 0) := (others => '0');
    signal mdio_driver : mdio_driver_record := init_mdio_driver_record;
    signal write_succeeded : boolean := false;
    signal read_succeeded : boolean := false;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(write_succeeded, "write did not succeed");
        check(read_succeeded, "read did not succeed");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_mdio_driver(mdio_driver, '1');

            case simulation_counter is
                when 5 => write_data_to_mdio(mdio_driver, x"00", x"01", x"aaaa");
                when others => -- do nothing
            end case;
            if mdio_write_is_ready(mdio_driver) then
                write_succeeded <= true;
                read_data_from_mdio(mdio_driver, x"00", x"01");
            end if;
            if mdio_read_is_ready(mdio_driver) then
                read_succeeded <= true;
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------

    mdio_test : process(simulator_clock)
        
    begin
        if rising_edge(mdio_driver.mdio_clock) then
            if mdio_driver.MDIO_io_direction_is_out_when_1 = '1' then
                shift_register <= shift_register(14 downto 0) & mdio_driver.mdio_io_data_out;
            end if;
        end if; --rising_edge
    end process mdio_test;	

------------------------------------------------------------------------
end vunit_simulation;
