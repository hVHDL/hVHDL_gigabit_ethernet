library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.PCK_CRC32_D8.all;

package frame_transmitter_pkg is

    type frame_transmitter_record is record
        crc32                : std_logic_vector(31 downto 0);
        crc32_output         : std_logic_vector(31 downto 0);
        shift_register       : std_logic_vector(5 downto 0);
        crc_transmit_counter : natural range 0 to 7;
        output_byte          : std_logic_vector(7 downto 0);
    end record;

    constant init_frame_transmitter : frame_transmitter_record := ((others => '1'), (others => '0'), (others => '0'), 0, (others => '0'));

------------------------------------------------------------------------
    procedure create_frame_transmitter (
        signal self : inout frame_transmitter_record);
------------------------------------------------------------------------
    procedure shift_crc_output (
        signal self : inout frame_transmitter_record);
------------------------------------------------------------------------
    function transmitter_is_requested ( self : frame_transmitter_record)
        return boolean;
------------------------------------------------------------------------
    function get_word_to_be_transmitted ( self : frame_transmitter_record)
        return std_logic_vector;
------------------------------------------------------------------------
    function reverse_bit_order ( input : std_logic_vector )
        return std_logic_vector;
------------------------------------------------------------------------
    function get_crc_output ( input : std_logic_vector )
        return std_logic_vector ;
------------------------------------------------------------------------
    function get_crc_output_byte ( self : frame_transmitter_record)
        return std_logic_vector;
------------------------------------------------------------------------
    procedure calculate_crc (
        signal self : inout frame_transmitter_record);
------------------------------------------------------------------------
    function frame_has_been_transmitted ( self : frame_transmitter_record)
        return boolean;
------------------------------------------------------------------------
    procedure transmit_word (
        signal self : inout frame_transmitter_record;
        word_to_transmit : std_logic_vector(7 downto 0));
------------------------------------------------------------------------
end package frame_transmitter_pkg;

package body frame_transmitter_pkg is

--------------------------------------------------
    function "/="
    (
        left : std_logic_vector; right : integer
    )
    return boolean
    is
    begin
        return to_integer(unsigned(left)) /= right;
    end "/=";

--------------------------------------------------
    procedure create_frame_transmitter
    (
        signal self : inout frame_transmitter_record
    ) is
        constant all_ones : std_logic_vector(self.shift_register'range) := (others => '1');
        variable crc_output : std_logic_vector(31 downto 0);
    begin
        self.crc32 <= (others => '1');
        self.shift_register <= self.shift_register(self.shift_register'left-1 downto 0) & '0';

        calculate_crc(self);

        if (self.shift_register /= all_ones) then
            shift_crc_output(self);
            self.output_byte <= self.crc32_output(7 downto 0);
        end if;
    end create_frame_transmitter;

--------------------------------------------------
    procedure calculate_crc
    (
        signal self : inout frame_transmitter_record
    ) is
        variable crc_output : std_logic_vector(31 downto 0);
    begin
        if self.shift_register(0) = '1' then
            crc_output := nextCRC32_D8(reverse_bit_order(self.output_byte), self.crc32);
            self.crc32             <= crc_output;
            self.crc32_output      <= get_crc_output(crc_output);
        end if;
    end calculate_crc;

--------------------------------------------------
    procedure transmit_word
    (
        signal self : inout frame_transmitter_record;
        word_to_transmit : std_logic_vector(7 downto 0)
    ) is
    begin
        self.output_byte <= word_to_transmit;
        self.shift_register(0) <= '1';
    end transmit_word;
--------------------------------------------------
    procedure shift_crc_output
    (
        signal self : inout frame_transmitter_record
    ) is
    begin
        self.crc32_output <= x"00" & self.crc32_output(31 downto 8);
    end shift_crc_output;

--------------------------------------------------
    function transmitter_is_requested
    (
        self : frame_transmitter_record
    )
    return boolean
    is
    begin
        return self.shift_register /= 0 and self.shift_register /= 1;
    end transmitter_is_requested;
--------------------------------------------------
    function get_word_to_be_transmitted
    (
        self : frame_transmitter_record
    )
    return std_logic_vector 
    is
        variable output : std_logic_vector(7 downto 0);
    begin
        if self.shift_register(0) = '1' then
            output := self.output_byte;
        else
            output := self.crc32_output(7 downto 0);
        end if;
        return output;
    end get_word_to_be_transmitted;
--------------------------------------------------
    function get_crc_output_byte
    (
        self : frame_transmitter_record
    )
    return std_logic_vector 
    is
    begin
        return self.crc32_output(7 downto 0);
    end get_crc_output_byte;

--------------------------------------------------
    function frame_has_been_transmitted
    (
        self : frame_transmitter_record
    )
    return boolean
    is
        constant last_one : std_logic_vector(self.shift_register'range) := (self.shift_register'left => '1', others => '0');
    begin
        return self.shift_register = last_one;
    end frame_has_been_transmitted;
--------------------------------------------------
    function reverse_bit_order
    (
        input : std_logic_vector 
    )
    return std_logic_vector 
    is
        variable return_value : std_logic_vector(input'reverse_range);
    begin
        for i in input'range loop
            return_value(i) := input(i);
        end loop;

        return return_value;
        
    end reverse_bit_order;
--------------------------------------------------
    function get_crc_output
    (
        input : std_logic_vector 
    )
    return std_logic_vector 
    is
    begin
        return not reverse_bit_order(input);
    end get_crc_output;
--------------------------------------------------

end package body frame_transmitter_pkg;
------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.PCK_CRC32_D8.all;
    use work.frame_transmitter_pkg.all;

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
    type bytearray is array (natural range <>) of std_logic_vector(7 downto 0);
    constant c_example_frame : bytearray :=(x"00",x"11",x"22",x"33",x"44",x"55",x"c8",x"7f",x"54",x"54",x"57",x"cd",x"90",x"00",x"48",x"65",x"6c",x"6c",x"6f",x"2c",x"20",x"57",x"6f",x"72",x"6c",x"64",x"21",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"c9",x"92",x"2a",x"86");
    signal example_frame : bytearray(c_example_frame'range) := c_example_frame;

    signal crc_successful : boolean := false;

    signal self : frame_transmitter_record := init_frame_transmitter;
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
    crc32        <= self.crc32;
    crc32_output <= self.crc32_output;

    get_output : process(self)
    begin
        if transmitter_is_requested(self) then
            byte_out <= get_word_to_be_transmitted(self);
        end if;
    end process get_output;	

    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_frame_transmitter(self);
            if transmit_counter > 0 then
                transmit_counter <= transmit_counter - 1;
                example_frame <= example_frame(example_frame'left+1 to example_frame'right) & x"00";
                transmit_word(self, example_frame(example_frame'left));
            end if;

            case simulation_counter is
                WHEN 15 => transmit_counter <= example_frame'high + 1;
                when others => --do nothing
            end case;

            output_shift_register <= get_word_to_be_transmitted(self) & output_shift_register(31 downto 8);
            if frame_has_been_transmitted(self) then
                crc_successful <= (output_shift_register = x"2144df1c");
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
