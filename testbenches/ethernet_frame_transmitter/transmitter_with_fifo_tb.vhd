LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.frame_transmitter_pkg.all;

    use work.transmit_test_pkg.bytearray;
    use work.transmit_test_pkg.c_example_frame;

    use work.fifo_pkg.all;

entity transmitter_with_fifo_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of transmitter_with_fifo_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal example_frame : bytearray(c_example_frame'range) := c_example_frame;

    signal crc_successful : boolean := false;

    signal frame_transmitter : frame_transmitter_record := init_frame_transmitter;
    signal output_byte  : std_logic_vector(7 downto 0);

    signal shift_counter : natural :=0;
    signal byte_out : std_logic_vector(7 downto 0);

    signal transmit_counter : natural := 0;

    signal output_shift_register : std_logic_vector(31 downto 0);

    signal transmitter_requested : boolean := false;
    signal transmitter_ready : boolean := false;

    signal fifo_read_in   : fifo_read_input_record;
    signal fifo_read_out  : fifo_read_output_record;
    signal fifo_write_in  : fifo_write_input_record;
    signal fifo_write_out : fifo_write_output_record;
    signal reset : std_logic := '1';


begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;

        if run("crc") then
            check(crc_successful, "checksum was not 2144df1c");
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
------------------------------------------------------------------------
            -- fifo setup
            init_fifo_read(fifo_read_in);
            init_fifo_write(fifo_write_in);
            reset <= '0';
------------------------------------------------------------------------
            create_frame_transmitter(frame_transmitter);
------------------------------------------------------------------------
            -- test code
            case simulation_counter is
                WHEN 15 => transmit_counter <= example_frame'high + 1;
                when others => --do nothing
            end case;

            if transmit_counter > 0 then
                transmit_counter <= transmit_counter - 1;
                example_frame <= example_frame(example_frame'left+1 to example_frame'right) & x"00";
                write_data_to_fifo(fifo_write_in, example_frame(example_frame'left));
                -- transmit_word(frame_transmitter, example_frame(example_frame'left));
            end if;

            if transmit_counter = 0 and fifo_can_be_read(fifo_read_out) then
                request_data_from_fifo(fifo_read_in);
            end if;

            if fifo_read_is_ready(fifo_read_out) then
                transmit_word(frame_transmitter, get_data_from_fifo(fifo_read_out));
            end if;

            if transmitter_is_requested(frame_transmitter) then
                byte_out              <= get_word_to_be_transmitted(frame_transmitter);
                output_shift_register <= get_word_to_be_transmitted(frame_transmitter) & output_shift_register(31 downto 8);
            else
                byte_out              <= x"ff";
            end if;

            if frame_has_been_transmitted(frame_transmitter) then
                crc_successful <= (output_shift_register = x"2144df1c");
            end if;

            transmitter_requested <= transmitter_is_requested(frame_transmitter);
            transmitter_ready     <= frame_has_been_transmitted(frame_transmitter);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_fifo : entity work.fifo
    port map(simulator_clock, reset, fifo_read_in, fifo_read_out, fifo_write_in, fifo_write_out);
------------------------------------------------------------------------
end vunit_simulation;
