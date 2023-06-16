library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.fpga_ddio_record_pkg.fpga_ddio_record;

package ethernet_rx_ddio_pkg is

------------------------------------------------------------------------
    alias ethernet_rx_ddio_FPGA_input_group is fpga_ddio_record;
    
------------------------------------------------------------------------
    type ethernet_rx_ddio_data_output_group is record
        rx_ctl : std_logic_vector(1 downto 0);
        ethernet_rx_byte : std_logic_vector(7 downto 0);
        byte_is_ready : boolean;
    end record;
    
------------------------------------------------------------------------
    function get_byte ( ethernet_rx_output : ethernet_rx_ddio_data_output_group)
        return std_logic_vector;
------------------------------------------------------------------------
    function get_reversed_byte (
        ethernet_rx_output : ethernet_rx_ddio_data_output_group)
        return std_logic_vector;
------------------------------------------------------------------------
    function get_byte_with_inverted_bit_order (
        ethernet_rx_output : ethernet_rx_ddio_data_output_group)
        return std_logic_vector;
------------------------------------------------------------------------
    function ethernet_rx_is_active ( ethernet_rx_ddr_output : ethernet_rx_ddio_data_output_group)
        return boolean;
------------------------------------------------------------------------
    function byte_is_ready ( ethernet_rx_ddr_output : ethernet_rx_ddio_data_output_group)
        return boolean;
------------------------------------------------------------------------
end package ethernet_rx_ddio_pkg;

    -- signal ethernet_rx_ddio_clocks   : ethernet_rx_ddio_clock_group;
    -- signal ethernet_rx_ddio_FPGA_out : ethernet_rx_ddio_FPGA_output_group;
    -- signal ethernet_rx_ddio_data_in  : ethernet_rx_ddio_data_output_group;
    
    -- u_ethernet_rx_ddio_pkg : ethernet_rx_ddio_pkg
    -- port map( ethernet_rx_ddio_clocks,
    --	  ethernet_rx_ddio_FPGA_out,
    --	  ethernet_rx_ddio_data_in);

package body ethernet_rx_ddio_pkg is

    constant transmit_enabled : std_logic_vector(1 downto 0) := "11";
    constant transmit_error : std_logic_vector(1 downto 0) := "10";
------------------------------------------------------------------------
    function get_reversed_byte
    (
        ethernet_rx_output : ethernet_rx_ddio_data_output_group
    )
    return std_logic_vector 
    is
        variable byte_reversed : std_logic_vector(7 downto 0);
    begin

        byte_reversed := ethernet_rx_output.ethernet_rx_byte(0) &
                         ethernet_rx_output.ethernet_rx_byte(1) &
                         ethernet_rx_output.ethernet_rx_byte(2) &
                         ethernet_rx_output.ethernet_rx_byte(3) &
                         ethernet_rx_output.ethernet_rx_byte(4) &
                         ethernet_rx_output.ethernet_rx_byte(5) &
                         ethernet_rx_output.ethernet_rx_byte(6) &
                         ethernet_rx_output.ethernet_rx_byte(7);

        return byte_reversed; 

    end get_reversed_byte;
------------------------------------------------------------------------
    function get_byte_with_inverted_bit_order
    (
        ethernet_rx_output : ethernet_rx_ddio_data_output_group
    )
    return std_logic_vector 
    is
        variable inverted_byte : std_logic_vector(7 downto 0);
    begin

        inverted_byte := ethernet_rx_output.ethernet_rx_byte(3) &
                         ethernet_rx_output.ethernet_rx_byte(2) &
                         ethernet_rx_output.ethernet_rx_byte(1) &
                         ethernet_rx_output.ethernet_rx_byte(0) &
                         ethernet_rx_output.ethernet_rx_byte(7) &
                         ethernet_rx_output.ethernet_rx_byte(6) &
                         ethernet_rx_output.ethernet_rx_byte(5) &
                         ethernet_rx_output.ethernet_rx_byte(4);

        return inverted_byte; 

        
    end get_byte_with_inverted_bit_order;

------------------------------------------------------------------------
    function ethernet_rx_is_active
    (
        ethernet_rx_ddr_output : ethernet_rx_ddio_data_output_group
    )
    return boolean
    is
    begin
        if ethernet_rx_ddr_output.rx_ctl = transmit_enabled then
            return true;
        else
            return false;
        end if;
        
    end ethernet_rx_is_active;

    function byte_is_ready
    (
        ethernet_rx_ddr_output : ethernet_rx_ddio_data_output_group
    )
    return boolean
    is
    begin
        return ethernet_rx_ddr_output.byte_is_ready;
        
    end byte_is_ready;
------------------------------------------------------------------------
------------------------------------------------------------------------

    function get_byte
    (
        ethernet_rx_output : ethernet_rx_ddio_data_output_group
    )
    return std_logic_vector 
    is
        variable byte_reversed : std_logic_vector(7 downto 0);
    begin
        byte_reversed := ethernet_rx_output.ethernet_rx_byte(4) &
                         ethernet_rx_output.ethernet_rx_byte(5) &
                         ethernet_rx_output.ethernet_rx_byte(6) &
                         ethernet_rx_output.ethernet_rx_byte(7) &
                         ethernet_rx_output.ethernet_rx_byte(0) &
                         ethernet_rx_output.ethernet_rx_byte(1) &
                         ethernet_rx_output.ethernet_rx_byte(2) &
                         ethernet_rx_output.ethernet_rx_byte(3);
        return byte_reversed;
    end get_byte;

------------------------------------------------------------------------
end package body ethernet_rx_ddio_pkg;
