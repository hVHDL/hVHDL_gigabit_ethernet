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

end package ethernet_rx_pkg;

package body ethernet_rx_pkg is

end package body ethernet_rx_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------
