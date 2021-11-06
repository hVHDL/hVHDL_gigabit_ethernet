library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;
    use work.ethernet_tx_ddio_pkg.all;

-- entity ethernet_tx_ddio is
--     port (
        -- ethernet_tx_ddio_clocks : in ethernet_rx_ddr_clock_group; 
--         ethernet_tx_ddio_FPGA_out : out ethernet_tx_ddio_pkg_FPGA_output_group;
--         ethernet_tx_ddio_data_in  : in ethernet_tx_ddio_pkg_data_input_group
--     );
-- end entity;

architecture cl10_tx_ddio of ethernet_tx_ddio is

    component ethddio_tx IS
        PORT
        (
            datain_h : IN STD_LOGIC_VECTOR (4 DOWNTO 0);
            datain_l : IN STD_LOGIC_VECTOR (4 DOWNTO 0);
            outclock : IN STD_LOGIC ;
            dataout  : OUT STD_LOGIC_VECTOR (4 DOWNTO 0)
        );
    END component;

    signal ddio_data_out_h : std_logic_vector(4 downto 0);
    signal ddio_data_out_l : std_logic_vector(4 downto 0);
    signal dataout         : STD_LOGIC_VECTOR (4 DOWNTO 0);

------------------------------------------------------------------------
begin
    ethernet_tx_ddio_FPGA_out <= ( tx_ctl => dataout(4),
                                 rgmii_tx => dataout(3 downto 0));

    ddio_data_out_l <= ethernet_tx_ddio_data_in.tx_ctl(0) & ethernet_tx_ddio_data_in.tx_byte(3 downto 0);
    ddio_data_out_h <= ethernet_tx_ddio_data_in.tx_ctl(1) & ethernet_tx_ddio_data_in.tx_byte(7 downto 4);
------------------------------------------------------------------------
    u_ethddio : ethddio_tx
        PORT map(
            datain_h => ddio_data_out_h                      ,
            datain_l => ddio_data_out_l                      ,
            outclock => ethernet_tx_ddio_clocks.tx_ddr_clock ,
            dataout  => dataout
        );

------------------------------------------------------------------------
end cl10_tx_ddio;
