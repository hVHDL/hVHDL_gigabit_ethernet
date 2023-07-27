library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ethernet_rx_pkg is

    type ethernet_rx_input_record is record
        empty_ram : boolean;
    end record;

    type ethernet_rx_output_record is record
        frame_is_received        : boolean;
        number_of_received_bytes : natural range 0 to 2047;
        start_address            : natural range 0 to 2047;
        ram_is_flushed           : boolean;
    end record;

------------------------------------------------------------------------
    function ethernet_frame_is_received ( self : ethernet_rx_output_record)
        return boolean;
------------------------------------------------------------------------
    function get_start_address ( self : ethernet_rx_output_record)
        return integer;
------------------------------------------------------------------------
    function get_number_of_received_bytes ( self : ethernet_rx_output_record)
        return integer;
------------------------------------------------------------------------

end package ethernet_rx_pkg;

package body ethernet_rx_pkg is

------------------------------------------------------------------------
    function ethernet_frame_is_received
    (
        self : ethernet_rx_output_record
    )
    return boolean
    is
    begin
        return self.frame_is_received;
    end ethernet_frame_is_received;

------------------------------------------------------------------------
    function get_start_address
    (
        self : ethernet_rx_output_record
    )
    return integer
    is
    begin
        return self.start_address;
    end get_start_address;

------------------------------------------------------------------------
    function get_number_of_received_bytes
    (
        self : ethernet_rx_output_record
    )
    return integer
    is
    begin
        return self.number_of_received_bytes;
    end get_number_of_received_bytes;

end package body ethernet_rx_pkg;
------------------------------------------------------------------------
