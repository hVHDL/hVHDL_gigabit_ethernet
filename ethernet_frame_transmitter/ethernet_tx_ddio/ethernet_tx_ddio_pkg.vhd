library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet_clocks_pkg.all;

package ethernet_tx_ddio_pkg is

------------------------------------------------------------------------
    type ethernet_tx_ddio_FPGA_output_group is record
        tx_ctl   : std_logic;
        rgmii_tx : std_logic_vector(3 downto 0);
    end record;
    
------------------------------------------------------------------------
    type ethernet_tx_ddio_data_input_group is record
        tx_byte      : std_logic_vector(7 downto 0);
        tx_ctl       : std_logic_vector(1 downto 0);
    end record;
    
------------------------------------------------------------------------
    component ethernet_tx_ddio is
        port (
            ethernet_tx_ddio_clocks : in ethernet_tx_ddr_clock_group; 
            ethernet_tx_ddio_FPGA_out : out ethernet_tx_ddio_FPGA_output_group; 
            ethernet_tx_ddio_data_in : in ethernet_tx_ddio_data_input_group
        );
    end component ethernet_tx_ddio;

------------------------------------------------------------------------
    procedure init_ethernet_tx_ddio (
        signal ethernet_tx_ddio_input : out ethernet_tx_ddio_data_input_group);
------------------------------------------------------------------------
    procedure transmit_8_bits_of_data (
        signal ethernet_tx_ddio_input : out ethernet_tx_ddio_data_input_group;
        data_to_output : in integer);

------------------------------------------------------------------------
    procedure transmit_8_bits_of_data (
        signal ethernet_tx_ddio_input : out ethernet_tx_ddio_data_input_group;
        data_to_output : in std_logic_vector(7 downto 0));

------------------------------------------------------------------------
end package ethernet_tx_ddio_pkg;

    -- signal ethernet_tx_ddio_clocks   : ethernet_tx_ddr_clock_group;
    -- signal ethernet_tx_ddio_FPGA_out : ethernet_tx_ddio_FPGA_output_group;
    -- signal ethernet_tx_ddio_data_in  : ethernet_tx_ddio_data_input_group;
    
    -- u_ethernet_tx_ddio_pkg : ethernet_tx_ddio_pkg
    -- port map( ethernet_tx_ddio_clocks,
    --	  ethernet_tx_ddio_FPGA_out,
    --	  ethernet_tx_ddio_data_in);

package body ethernet_tx_ddio_pkg is

------------------------------------------------------------------------
    procedure init_ethernet_tx_ddio
    (
        signal ethernet_tx_ddio_input : out ethernet_tx_ddio_data_input_group
    ) is
    begin
        ethernet_tx_ddio_input.tx_ctl <= "00";
        ethernet_tx_ddio_input.tx_byte <= (others => '0');
    end init_ethernet_tx_ddio;

------------------------------------------------------------------------
    procedure transmit_8_bits_of_data
    (
        signal ethernet_tx_ddio_input : out ethernet_tx_ddio_data_input_group;
        data_to_output : in std_logic_vector(7 downto 0)
    ) is
    begin
        ethernet_tx_ddio_input.tx_ctl  <= "11";
        ethernet_tx_ddio_input.tx_byte <= data_to_output(4) & 
                                          data_to_output(5) &
                                          data_to_output(6) &
                                          data_to_output(7) &
                                          data_to_output(0) &
                                          data_to_output(1) &
                                          data_to_output(2) &
                                          data_to_output(3);
    end transmit_8_bits_of_data;

------------------------------------------------------------------------
    procedure transmit_8_bits_of_data
    (
        signal ethernet_tx_ddio_input : out ethernet_tx_ddio_data_input_group;
        data_to_output : in integer
    ) is
    begin
        transmit_8_bits_of_data(ethernet_tx_ddio_input, std_logic_vector(to_unsigned(data_to_output,8)));
    end transmit_8_bits_of_data;


------------------------------------------------------------------------
end package body ethernet_tx_ddio_pkg;
