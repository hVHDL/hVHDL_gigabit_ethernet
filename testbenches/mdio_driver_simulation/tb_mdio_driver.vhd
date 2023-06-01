LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.mdio_driver_pkg.all;

entity mdio_driver_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of mdio_driver_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal mdio_driver_FPGA_out   : mdio_driver_FPGA_output_group;
    signal mdio_driver_FPGA_inout : mdio_driver_FPGA_three_state_record;
    signal mdio_driver_data_in    : mdio_driver_data_input_group;
    signal mdio_driver_data_out   : mdio_driver_data_output_group;

    --------------------------------
    signal shift_register : std_logic_vector(15 downto 0);

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
            init_mdio_driver(mdio_driver_data_in);

            case simulation_counter is
                when 5 => write_data_to_mdio(mdio_driver_data_in, x"00", x"01", x"aaaa");
                when others => -- do nothing
            end case;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_mdio : entity work.mdio_driver
    port map(simulator_clock       ,
            mdio_driver_FPGA_out   ,
            mdio_driver_FPGA_inout ,
            mdio_driver_data_in    ,
            mdio_driver_data_out); 

    mdio_test : process(simulator_clock)
        
    begin
        if rising_edge(mdio_driver_FPGA_out.mdio_clock) then
            if mdio_driver_FPGA_out.mdio_data_is_out_when_1 = '1' then
                shift_register <= shift_register(14 downto 0) & mdio_driver_FPGA_inout.mdio_three_state_io_driver_FPGA_inout.MDIO_inout_data;
            end if;
        end if; --rising_edge
    end process mdio_test;	

------------------------------------------------------------------------
end vunit_simulation;
