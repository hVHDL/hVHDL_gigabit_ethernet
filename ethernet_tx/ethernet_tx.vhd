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


------------------------------------------------------------------------
    u_fifo : entity work.fifo
    port map(clock, reset, fifo_read_in, fifo_read_out, fifo_write_in, fifo_write_out);
------------------------------------------------------------------------
    process(clock)
    begin
        if rising_edge(clock) then
            reset <= '0';
            init_fifo_read(fifo_read_in);
            init_fifo_write(fifo_write_in);
            if tx_in.load_data then
                write_data_to_fifo(fifo_write_in, tx_in.byte_in);
            end if;
            tx_out.frame_has_been_transmitted <= frame_has_been_transmitted(frame_transmitter);

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
                        byte_out <= x"55";
                    end if;

                    if preamble_counter = 7 then
                        byte_out      <= x"d5";
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
end rtl;
