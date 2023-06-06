library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_rx_ddio_pkg.all;

-- entity ethernet_rx_ddio is
--     port (
--         ethernet_rx_ddio_clocks   : in ethernet_rx_ddio_pkg_clock_group;
--         ethernet_rx_ddio_FPGA_in  : out ethernet_rx_ddio_pkg_FPGA_input_group;
--         ethernet_rx_ddio_data_out : out ethernet_rx_ddio_pkg_data_output_group
--     );
-- end entity;

architecture cl10_rx_ddio of ethernet_rx_ddio is

    alias ddio_rx_clock is ethernet_rx_ddio_clocks.rx_ddr_clock;
    signal ddio_fpga_in : std_logic_vector(4 downto 0);
    alias ethernet_byte_to_fpga is ethernet_rx_ddio_data_out.ethernet_rx_byte;

    component ethddio_rx IS
	PORT
	(
		datain    : IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		inclock   : IN STD_LOGIC ;
		dataout_h : OUT STD_LOGIC_VECTOR (4 DOWNTO 0);
		dataout_l : OUT STD_LOGIC_VECTOR (4 DOWNTO 0)
	);
    END component;


	signal dataout_h : STD_LOGIC_VECTOR (4 DOWNTO 0);
	signal dataout_l : STD_LOGIC_VECTOR (4 DOWNTO 0);

------------------------------------------------------------------------
begin

    ddio_fpga_in(4) <= ethernet_rx_ddio_FPGA_in.rx_ctl;
    ddio_fpga_in(3 downto 0) <= ethernet_rx_ddio_FPGA_in.ethernet_rx_ddio_in;

    ethernet_rx_ddio_data_out <= (rx_ctl           => dataout_l(4)          & dataout_h(4),
                                  ethernet_rx_byte => dataout_l(3 downto 0) & dataout_h(3 downto 0));

------------------------------------------------------------------------
    u_ethddio : ethddio_rx
        PORT map(
            ddio_fpga_in  ,
            ddio_rx_clock ,
            dataout_h     ,
            dataout_l
        );

------------------------------------------------------------------------
end cl10_rx_ddio;
