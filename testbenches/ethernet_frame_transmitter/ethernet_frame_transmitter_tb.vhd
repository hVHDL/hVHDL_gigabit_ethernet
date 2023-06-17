library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package frame_transmitter_pkg is

    type frame_transmitter_record is record
        crc32 : std_logic_vector(31 downto 0);
        crc_output : std_logic_vector(31 downto 0);
    end record;

    constant init_frame_transmitter : frame_transmitter_record := ((others => '1'), (others => '0'));

    function reverse_bit_order ( input : std_logic_vector )
        return std_logic_vector;

    function get_crc_output ( input : std_logic_vector )
        return std_logic_vector ;

end package frame_transmitter_pkg;

package body frame_transmitter_pkg is
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

    signal crc32 : std_logic_vector(31 downto 0) := (others => '1');
    signal crc32_output : std_logic_vector(31 downto 0) := (others => '0');
    signal output_byte : std_logic_vector(7 downto 0);


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

    stimulus : process(simulator_clock)


        variable crc_output : std_logic_vector(31 downto 0);

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            example_frame <= example_frame(example_frame'left+1 to example_frame'right) & x"00";
            if simulation_counter <= example_frame'high then
                crc_output := nextCRC32_D8(reverse_bit_order(example_frame(example_frame'left)), crc32);
                crc32        <= crc_output;
                crc32_output <= get_crc_output(crc_output);
            end if;

            if simulation_counter = example_frame'high + 1 then
                crc_successful <= (crc32_output = x"2144df1c");
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
