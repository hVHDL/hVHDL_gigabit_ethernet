library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_rx_ddio_pkg.all;

entity ethernet_rx_ddio is
    port (
        clk : in std_logic;
        ethernet_rx_ddio_fpga_in : in ethernet_rx_ddio_FPGA_input_group;
        ethernet_ddio_out : out ethernet_rx_ddio_data_output_group
    );
end entity ethernet_rx_ddio;


architecture efinix_rtl of ethernet_rx_ddio is

    alias self is ethernet_rx_ddio_fpga_in;

begin

    clockin : process(clk)
        
    begin
        if rising_edge(clk) then
            ethernet_ddio_out <= (rx_ctl => (self.fpga_IO_HI(4), self.fpga_IO_LO(4)), 
                                  ethernet_rx_byte => 
                                      (self.fpga_IO_LO(0) ,
                                        self.fpga_IO_LO(1),
                                        self.fpga_IO_LO(2),
                                        self.fpga_IO_LO(3),
                                        self.fpga_IO_HI(0),
                                        self.fpga_IO_HI(1),
                                        self.fpga_IO_HI(2),
                                        self.fpga_IO_HI(3)), 
                                    byte_is_ready => (std_logic_vector'(self.fpga_IO_HI(4), self.fpga_IO_LO(4)) = "11"));
                
        end if; --rising_edge
    end process clockin;	
    
    end efinix_rtl;
------------------------------------------------------------------------
