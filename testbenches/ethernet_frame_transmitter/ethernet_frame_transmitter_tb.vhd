LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.PCK_CRC32_D8.all;
    use work.frame_transmitter_pkg.all;

    use work.transmit_test_pkg.bytearray;
    use work.transmit_test_pkg.c_example_frame;

entity ethernet_frame_transmitter_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of ethernet_frame_transmitter_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal example_frame : bytearray(c_example_frame'range) := c_example_frame;

    signal crc_successful : boolean := false;

    signal frame_transmitter : frame_transmitter_record := init_frame_transmitter;
    signal crc32        : std_logic_vector(31 downto 0) := (others => '1');
    signal crc32_output : std_logic_vector(31 downto 0) := (others => '0');
    signal output_byte  : std_logic_vector(7 downto 0);

    signal shift_counter : natural :=0;
    signal byte_out : std_logic_vector(7 downto 0);

    signal transmit_counter : natural := 0;

    signal output_shift_register : std_logic_vector(31 downto 0);


begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        -- if run("crc was calculated correctly") then
            check(crc_successful, "checksum was not 2144df1c");
        -- end if;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------
    crc32        <= frame_transmitter.crc32;
    crc32_output <= frame_transmitter.crc32_output;

    get_output : process(frame_transmitter)
    begin
        if transmitter_is_requested(frame_transmitter) then
            byte_out <= get_word_to_be_transmitted(frame_transmitter);
        end if;
    end process get_output;	

    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_frame_transmitter(frame_transmitter);
            if transmit_counter > 0 then
                transmit_counter <= transmit_counter - 1;
                example_frame <= example_frame(example_frame'left+1 to example_frame'right) & x"00";
                transmit_word(frame_transmitter, example_frame(example_frame'left));
            end if;

            case simulation_counter is
                WHEN 15 => transmit_counter <= example_frame'high + 1;
                when others => --do nothing
            end case;

            output_shift_register <= get_word_to_be_transmitted(frame_transmitter) & output_shift_register(31 downto 8);
            if frame_has_been_transmitted(frame_transmitter) then
                crc_successful <= (output_shift_register = x"2144df1c");
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
