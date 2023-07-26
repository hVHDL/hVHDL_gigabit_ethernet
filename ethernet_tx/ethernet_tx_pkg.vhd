LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

package ethernet_tx_pkg is

    type ethernet_tx_input_record is record
        request_ethernet_frame : boolean;
        byte_in                : std_logic_vector(7 downto 0);
        load_data              : boolean;
    end record;

    type ethernet_tx_output_record is record
        frame_has_been_transmitted : boolean;
        frame_is_being_transmitted : boolean;
    end record;

    procedure init_ethernet_tx (
        signal self : out ethernet_tx_input_record);

    procedure load_data_to_transmit_fifo (
        signal self : out ethernet_tx_input_record;
        data        : in std_logic_vector(7 downto 0));

    procedure request_ethernet_frame (
        signal self : out ethernet_tx_input_record);

    function tx_is_ready ( self : ethernet_tx_output_record)
    return boolean;

end package ethernet_tx_pkg;
------------------------------------------------------------------------
package body ethernet_tx_pkg is

    procedure init_ethernet_tx
    (
        signal self : out ethernet_tx_input_record
    ) is
    begin
        self.request_ethernet_frame <= false;
        self.load_data <= false;
    end init_ethernet_tx;

    procedure load_data_to_transmit_fifo
    (
        signal self : out ethernet_tx_input_record;
        data        : in std_logic_vector(7 downto 0)
    ) is
    begin
        self.load_data <= true;
        self.byte_in <= data;
        
    end load_data_to_transmit_fifo;

    procedure request_ethernet_frame
    (
        signal self : out ethernet_tx_input_record
    ) is
    begin
        self.request_ethernet_frame <= true;
    end request_ethernet_frame;

    function tx_is_ready
    (
        self : ethernet_tx_output_record
    )
    return boolean
    is
    begin
        return self.frame_has_been_transmitted;
        
    end tx_is_ready;

end package body ethernet_tx_pkg;
------------------------------------------------------------------------
