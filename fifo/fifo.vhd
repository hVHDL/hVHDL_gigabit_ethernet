------------------------------------------------------------------------
------------------------------------------------------------------------
-- package fifo_8b_pkg is new work.fifo_pkg
--     generic map(RAM_WIDTH => 8, RAM_DEPTH => 2048);

------------------------------------------------------------------------
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
    
    -- use work.fifo_8b_pkg.all;
    use work.fifo_pkg.all;

entity fifo is
  port (
    clk : in std_logic;
    rst : in std_logic;

    fifo_read_in  : in fifo_read_input_record;
    fifo_read_out : out fifo_read_output_record;

    fifo_write_in  : in fifo_write_input_record;
    fifo_write_out : out fifo_write_output_record
  );
end fifo;

architecture rtl of fifo is

    type ram_type is array (0 to RAM_DEPTH - 1) of std_logic_vector(fifo_write_in.data_to_be_written'range);
    signal ram : ram_type;

    subtype index_type is integer range ram_type'range;
    signal head : index_type;
    signal tail : index_type;

    signal empty_when_1 : std_logic;
    signal full_when_1 : std_logic;
    signal number_of_words_in_fifo : integer range RAM_DEPTH - 1 downto 0;

    ------------------------------------------------------------------------
    procedure increment_and_wrap(signal index : inout index_type) is
    begin
        if index = index_type'high then
            index <= index_type'low;
        else
            index <= index + 1;
        end if;
    end procedure;
    ------------------------------------------------------------------------

begin

    fifo_read_out.empty                   <= empty_when_1;
    fifo_read_out.number_of_words_in_fifo <= number_of_words_in_fifo;
    fifo_read_out.almost_empty            <= '1' when number_of_words_in_fifo <= 1 else '0';

    fifo_write_out.full_next <= '1' when number_of_words_in_fifo >= RAM_DEPTH - 2 else '0';
    fifo_write_out.full      <= full_when_1;
    empty_when_1             <= '1' when number_of_words_in_fifo = 0 else '0';
    full_when_1              <= '1' when number_of_words_in_fifo >= RAM_DEPTH - 1 else '0';

    create_fifo : process(clk)
    begin
        if rising_edge(clk) then
            ram(head) <= fifo_write_in.data_to_be_written;
            fifo_read_out.data_to_be_read <= ram(tail);

            if rst = '1' then
                head <= 0;
                tail <= 0;
                fifo_read_out.read_ready_when_1 <= '0';
            else
                if fifo_write_in.write_when_1 = '1' and full_when_1 = '0' then
                    increment_and_wrap(head);
                end if;

                fifo_read_out.read_ready_when_1 <= '0';
                if fifo_read_in.read_when_1 = '1' and empty_when_1 = '0' then
                    increment_and_wrap(tail);
                    fifo_read_out.read_ready_when_1 <= '1';
                end if;
            end if;
        end if;
    end process;

    update_number_of_words_in_fifo : process(head, tail)
    begin
        if head < tail then
            number_of_words_in_fifo <= head - tail + RAM_DEPTH;
        else
            number_of_words_in_fifo <= head - tail;
        end if;
    end process;

end architecture;
