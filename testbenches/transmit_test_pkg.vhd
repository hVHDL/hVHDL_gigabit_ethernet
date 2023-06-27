library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package transmit_test_pkg is

    type bytearray is array (natural range <>) of std_logic_vector(7 downto 0);
    constant c_example_frame : bytearray :=(x"00",x"11",x"22",x"33",x"44",x"55",x"c8",x"7f",x"54",x"54",x"57",x"cd",x"90",x"00",x"48",x"65",x"6c",x"6c",x"6f",x"2c",x"20",x"57",x"6f",x"72",x"6c",x"64",x"21",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"c9",x"92",x"2a",x"86");

end package transmit_test_pkg;
