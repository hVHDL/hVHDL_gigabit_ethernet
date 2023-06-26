library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package fifo_pkg is
    -- generic (RAM_WIDTH : natural;
    --         RAM_DEPTH : natural);
    constant RAM_WIDTH : integer := 8;
    constant RAM_DEPTH : integer := 2048;
------------------------------------------------------------------------

    type fifo_write_input_record is record
        write_when_1   : std_logic;
        data_to_be_written : std_logic_vector(RAM_WIDTH - 1 downto 0);
    end record;

    type fifo_write_output_record is record
        full       : std_logic;
        full_next  : std_logic;
    end record;

    type fifo_read_input_record is record
        read_when_1 : std_logic;
    end record;

    type fifo_read_output_record is record
        read_ready_when_1       : std_logic;
        data_to_be_read         : std_logic_vector(RAM_WIDTH - 1 downto 0);
        empty                   : std_logic;
        almost_empty            : std_logic;
        number_of_words_in_fifo : integer range RAM_DEPTH - 1 downto 0;
    end record;

------------------------------------------------------------------------
    procedure init_fifo_read (
        signal self : out fifo_read_input_record);
------------------------------------------------------------------------
    procedure request_data_from_fifo (
        signal self : out fifo_read_input_record);
------------------------------------------------------------------------
    function fifo_read_is_ready ( self : fifo_read_output_record) return boolean;
------------------------------------------------------------------------
    function get_number_of_words_in_fifo ( self : fifo_read_output_record) return integer;
------------------------------------------------------------------------
    function get_data_from_fifo ( self : fifo_read_output_record) return std_logic_vector ;
------------------------------------------------------------------------
    function fifo_almost_empty ( self : fifo_read_output_record) return boolean;
------------------------------------------------------------------------
    function fifo_empty ( self : fifo_read_output_record) return boolean;
------------------------------------------------------------------------
    function fifo_can_be_read ( self : fifo_read_output_record) return boolean;
------------------------------------------------------------------------
------------------------------------------------------------------------
    procedure init_fifo_write (
        signal self : out fifo_write_input_record);
------------------------------------------------------------------------
    procedure write_data_to_fifo (
        signal self : out fifo_write_input_record;
        data_to_be_written : in std_logic_vector);
------------------------------------------------------------------------

end package fifo_pkg;

package body fifo_pkg is

------------------------------------------------------------------------
    procedure init_fifo_read
    (
        signal self : out fifo_read_input_record
    ) is
    begin
        self.read_when_1 <= '0';
    end init_fifo_read;

------------------------------------------------------------------------
    procedure request_data_from_fifo
    (
        signal self : out fifo_read_input_record
    ) is
    begin
        self.read_when_1 <= '1';
    end request_data_from_fifo;

------------------------------------------------------------------------
    function fifo_read_is_ready
    (
        self : fifo_read_output_record
        
    ) return boolean is
    begin
        return self.read_ready_when_1 = '1';
    end fifo_read_is_ready;

------------------------------------------------------------------------
    function get_data_from_fifo
    (
        self : fifo_read_output_record
    )
    return std_logic_vector 
    is
    begin
        return self.data_to_be_read;
    end get_data_from_fifo;
------------------------------------------------------------------------
    function get_number_of_words_in_fifo
    (
        self : fifo_read_output_record
    )
    return integer
    is
    begin
        return self.number_of_words_in_fifo;
    end get_number_of_words_in_fifo;
------------------------------------------------------------------------
    function fifo_almost_empty
    (
        self : fifo_read_output_record
    )
    return boolean
    is
    begin
        return self.almost_empty = '1';
    end fifo_almost_empty;
------------------------------------------------------------------------
    function fifo_empty
    (
        self : fifo_read_output_record
    )
    return boolean
    is
    begin
        return self.empty = '1';
    end fifo_empty;
------------------------------------------------------------------------
    function fifo_can_be_read
    (
        self : fifo_read_output_record
    )
    return boolean
    is
    begin
        return (not fifo_almost_empty(self)) or (not fifo_empty(self));
    end fifo_can_be_read;
------------------------------------------------------------------------
------------------------------------------------------------------------
    procedure init_fifo_write
    (
        signal self : out fifo_write_input_record
    ) is
    begin
        self.write_when_1 <= '0';
    end init_fifo_write;

------------------------------------------------------------------------
    procedure write_data_to_fifo
    (
        signal self : out fifo_write_input_record;
        data_to_be_written : in std_logic_vector
    ) is
    begin
        self.write_when_1   <= '1';
        self.data_to_be_written <= data_to_be_written;
    end write_data_to_fifo;

end package body fifo_pkg;

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
------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.fifo_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity transmit_fifo_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of transmit_fifo_tb is

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

    signal catch_data : natural := 0;

    type std8_array is array (integer range 0 to 7) of std_logic_vector(7 downto 0);
    constant check_values : std8_array := (0 => x"ab", 1 => x"cd", 2 => x"ef", others => x"00"); 

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        if run("3_words_were_read_from_fifo") then
            check(catch_data = 3, "expected 3, got " & integer'image(catch_data));
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

            CASE simulation_counter is
                WHEN 10 => write_data_to_fifo(fifo_write_in, check_values(0));
                WHEN 11 => write_data_to_fifo(fifo_write_in, check_values(1));
                WHEN 12 => write_data_to_fifo(fifo_write_in, check_values(2));
                WHEN others => --do nothing
            end CASE;

            if simulation_counter > 50 then
                if fifo_can_be_read(fifo_read_out) then
                    request_data_from_fifo(fifo_read_in);
                end if;
            end if;

            if fifo_read_is_ready(fifo_read_out) then
                catch_data <= catch_data + 1;
                check(check_values(catch_data) = get_data_from_fifo(fifo_read_out));
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_fifo : entity work.fifo
    port map(simulator_clock, reset, fifo_read_in, fifo_read_out, fifo_write_in, fifo_write_out);
------------------------------------------------------------------------
end vunit_simulation;
