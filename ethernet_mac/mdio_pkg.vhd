library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- IEEE 802.3 clause 22 MDIO management interface.
-- Based on the mdio driver of hVHDL_gigabit_ethernet, rewritten with a full 32 bit
-- preamble and a configurable MDC frequency.
package mdio_pkg is

    type mdio_command is (none, read, write);

    type mdio_in_record is record
        command          : mdio_command;
        phy_address      : natural range 0 to 31;
        register_address : natural range 0 to 31;
        write_data       : std_logic_vector(15 downto 0);
    end record;

    constant init_mdio_in : mdio_in_record := (none, 0, 0, (others => '0'));

    type mdio_out_record is record
        is_ready            : boolean;
        transaction_is_done : boolean;
        read_data           : std_logic_vector(15 downto 0);
    end record;

    type mdio_fpga_out_record is record
        mdc      : std_logic;
        mdio_out : std_logic;
        mdio_oe  : std_logic;
    end record;

    -- standard clause 22 registers
    constant basic_control_register  : natural := 0;
    constant basic_status_register   : natural := 1;
    constant phy_identifier_1        : natural := 2;
    constant phy_identifier_2        : natural := 3;
    constant mmd_access_control      : natural := 13;
    constant mmd_access_data         : natural := 14;

------------------------------------------------------------------------
    procedure init_mdio (
        signal self : out mdio_in_record);

    procedure request_mdio_read (
        signal self      : out mdio_in_record;
        phy_address      : natural;
        register_address : natural);

    procedure request_mdio_write (
        signal self      : out mdio_in_record;
        phy_address      : natural;
        register_address : natural;
        data             : std_logic_vector(15 downto 0));

    function mdio_is_ready ( self : mdio_out_record) return boolean;
    function mdio_transaction_is_done ( self : mdio_out_record) return boolean;
    function get_mdio_read_data ( self : mdio_out_record) return std_logic_vector;

end package mdio_pkg;

package body mdio_pkg is

    procedure init_mdio
    (
        signal self : out mdio_in_record
    ) is
    begin
        self.command <= none;
    end init_mdio;

    procedure request_mdio_read
    (
        signal self      : out mdio_in_record;
        phy_address      : natural;
        register_address : natural
    ) is
    begin
        self.command          <= read;
        self.phy_address      <= phy_address;
        self.register_address <= register_address;
    end request_mdio_read;

    procedure request_mdio_write
    (
        signal self      : out mdio_in_record;
        phy_address      : natural;
        register_address : natural;
        data             : std_logic_vector(15 downto 0)
    ) is
    begin
        self.command          <= write;
        self.phy_address      <= phy_address;
        self.register_address <= register_address;
        self.write_data       <= data;
    end request_mdio_write;

    function mdio_is_ready ( self : mdio_out_record) return boolean is
    begin
        return self.is_ready;
    end mdio_is_ready;

    function mdio_transaction_is_done ( self : mdio_out_record) return boolean is
    begin
        return self.transaction_is_done;
    end mdio_transaction_is_done;

    function get_mdio_read_data ( self : mdio_out_record) return std_logic_vector is
    begin
        return self.read_data;
    end get_mdio_read_data;

end package body mdio_pkg;
