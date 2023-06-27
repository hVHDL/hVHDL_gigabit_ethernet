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
