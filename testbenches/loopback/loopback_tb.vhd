LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.transmit_test_pkg.c_example_frame;
    use work.ethernet_tx_pkg.all;

    use work.ethernet_frame_ram_read_pkg.all;
    use work.ethernet_frame_ram_write_pkg.all;
    use work.ethernet_frame_receiver_pkg.all;
    use work.ethernet_rx_ddio_pkg.all;
    use work.ethernet_rx_pkg.all;

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

    signal output_shift_register : std_logic_vector(31 downto 0);
    signal tx_was_completed : boolean := false;

    signal ram_read_control_port : ram_read_control_group := init_ram_read_port;
    signal ram_read_out_port : ram_read_output_group := ram_read_output_init;

    signal write_port : ram_write_control_record := init_ram_write_control;
    signal ram_address : integer := 0;

    signal ethernet_ddio : std_logic_vector(9 downto 0) := (others => '0');
    signal ram_reader : ram_reader_record := init_ram_reader;
    signal ram_shift_register : std_logic_vector(31 downto 0) := (others => '0');

    signal rx_out : ethernet_rx_output_record;


    signal crc_was_read_from_ram : boolean := false;

    signal empty_ram : boolean := false;


begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;

        if run("check that transmitter was run") then
            check(tx_was_completed, "transmitter was not run");

        elsif run("frame was sent successfully") then
            check(output_shift_register = x"2144df1c", "frame was not successfully sent");

        elsif run("crc was read from ram") then
            check(crc_was_read_from_ram, "crc was not read from ram");

        elsif run("crc was correct") then
            check(ram_shift_register = x"2144df1c", "crc was not read from ram");

        end if;
        
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

        constant number_of_words_in_frame : natural := c_example_frame'high - 3;

        function write_ethernet_ddio
        (
            byte_in : std_logic_vector 
        ) return std_logic_vector is
            variable return_value : std_logic_vector(9 downto 0);
        begin
            return_value := '1' & 
                            byte_in(3) &
                            byte_in(2) &
                            byte_in(1) &
                            byte_in(0) &
                            '1' &
                            byte_in(7) &
                            byte_in(6) &
                            byte_in(5) &
                            byte_in(4);
            return return_value;

        end write_ethernet_ddio;

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

            ethernet_ddio <= (others => '0');
            if tx_is_active then
                output_shift_register <= byte_out & output_shift_register(31 downto 8);
                ethernet_ddio <= write_ethernet_ddio(byte_out);
            end if;

            if tx_is_ready(tx_out) then
                tx_was_completed <= tx_is_ready(tx_out);
            end if;

            create_ram_reader(ram_reader, ram_read_control_port, ram_read_out_port, ram_shift_register);
            if ethernet_frame_is_received(rx_out) then
                load_ram_with_offset_to_shift_register(ram_reader, number_of_words_in_frame-4, 4);
            end if;
            if ram_is_buffered_to_shift_register(ram_reader) then
                crc_was_read_from_ram <= true;

            end if;

            empty_ram <= simulation_counter = 163;



        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_ethernet_tx : entity work.ethernet_tx
    port map(simulator_clock, tx_in, tx_out, tx_is_active, byte_out);
------------------------------------------------------------------------
    u_dpram : entity work.dpram
    port map(simulator_clock, ram_read_control_port,ram_read_out_port, simulator_clock, write_port);

    u_ethernet_rx : entity work.ethernet_rx
    port map(
        clock      => simulator_clock,
        ddio_input => ethernet_ddio,
        rx_out         => rx_out,
        empty_ram      => empty_ram,
        write_port     => write_port);
------------------------------------------------------------------------
end vunit_simulation;
