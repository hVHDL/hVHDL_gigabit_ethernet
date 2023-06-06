library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package fpga_ddio_record_pkg is

    type fpga_ddio_record is record
        fpga_IO_HI : std_logic_vector(4 downto 0);
        fpga_IO_LO : std_logic_vector(4 downto 0);
    end record;

end package fpga_ddio_record_pkg;
