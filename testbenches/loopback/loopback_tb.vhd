LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

package ethernet_tx_pkg is

    type ethernet_tx_input_record is record
        request_ethernet_frame : boolean;
        byte_in : std_logic_vector(7 downto 0);
        load_data : boolean;
    end record;

    type ethernet_tx_output_record is record
        frame_has_been_transmitted : boolean;
        frame_is_being_transmitted : boolean;
    end record;

    procedure init_ethernet_tx (
        signal self : out ethernet_tx_input_record);

    procedure load_data_to_transmit_fifo (
        signal self : out ethernet_tx_input_record;
        data        : in std_logic_vector(7 downto 0));

    procedure request_ethernet_frame (
        signal self : out ethernet_tx_input_record);

end package ethernet_tx_pkg;
------------------------------------------------------------------------
package body ethernet_tx_pkg is

    procedure init_ethernet_tx
    (
        signal self : out ethernet_tx_input_record
    ) is
    begin
        self.request_ethernet_frame <= false;
        self.load_data <= false;
    end init_ethernet_tx;

    procedure load_data_to_transmit_fifo
    (
        signal self : out ethernet_tx_input_record;
        data        : in std_logic_vector(7 downto 0)
    ) is
    begin
        self.load_data <= true;
        self.byte_in <= data;
        
    end load_data_to_transmit_fifo;

    procedure request_ethernet_frame
    (
        signal self : out ethernet_tx_input_record
    ) is
    begin
        self.request_ethernet_frame <= true;
    end request_ethernet_frame;

end package body ethernet_tx_pkg;
------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.ethernet_tx_pkg.all;
    use work.frame_transmitter_pkg.all;

entity ethernet_tx is
    port (
        clock  : in std_logic;
        tx_in  : in ethernet_tx_input_record;
        tx_out : out ethernet_tx_output_record;

        tx_is_active : out boolean;
        byte_out     : out std_logic_vector(7 downto 0)
    );
end entity ethernet_tx;


architecture rtl of ethernet_tx is

    use work.fifo_pkg.all;
    signal reset : std_logic := '1';
    signal fifo_read_in   : fifo_read_input_record;
    signal fifo_read_out  : fifo_read_output_record;
    signal fifo_write_in  : fifo_write_input_record;
    signal fifo_write_out : fifo_write_output_record;
    signal preamble_counter : natural range 0 to 8 := 8;
    signal preamble_counter_is_ready : boolean := false;

    signal frame_transmitter : frame_transmitter_record := init_frame_transmitter;

    signal transmit_data : boolean := false;

    type list_of_tx_states is (idle, transmit_preamble, transmit_frame);
    signal tx_state : list_of_tx_states := idle;

begin

    process(clock)
    begin
        if rising_edge(clock) then
            reset <= '0';
            init_fifo_read(fifo_read_in);
            init_fifo_write(fifo_write_in);
            if tx_in.load_data then
                write_data_to_fifo(fifo_write_in, tx_in.byte_in);
            end if;

            byte_out     <= x"ff";
            tx_is_active <= false;

            CASE tx_state is
                WHEN idle =>
                    if tx_in.request_ethernet_frame then
                        preamble_counter <= 0;
                        tx_state <= transmit_preamble;
                    end if;

                WHEN transmit_preamble =>
                    tx_is_active <= true;
                    if preamble_counter < 8 then
                        preamble_counter <= preamble_counter + 1;
                        byte_out <= x"aa";
                    end if;

                    if preamble_counter = 7 then
                        byte_out      <= x"ab";
                        tx_state <= transmit_frame;
                    end if;

                    if preamble_counter = 7-3 then
                        transmit_data <= true;
                    end if;
                WHEN transmit_frame =>
                    if frame_has_been_transmitted(frame_transmitter) then
                        tx_state <= idle;
                    end if;
            end CASE;

            if transmit_data and fifo_can_be_read(fifo_read_out) then
                request_data_from_fifo(fifo_read_in);
            end if;

            if fifo_almost_empty(fifo_read_out) then
                transmit_data <= false;
            end if;

            create_frame_transmitter(frame_transmitter);
            if fifo_read_is_ready(fifo_read_out) then
                transmit_word(frame_transmitter, get_data_from_fifo(fifo_read_out));
            end if;

            if transmitter_is_requested(frame_transmitter) then
                byte_out     <= get_word_to_be_transmitted(frame_transmitter);
                tx_is_active <= transmitter_is_requested(frame_transmitter);
            end if;

        end if; --rising_edge
    end process;	


------------------------------------------------------------------------
    u_fifo : entity work.fifo
    port map(clock, reset, fifo_read_in, fifo_read_out, fifo_write_in, fifo_write_out);
------------------------------------------------------------------------
end rtl;
------------------------------------------------------------------------
------------------------------------------------------------------------
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

            if fill_counter = 10 then
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
