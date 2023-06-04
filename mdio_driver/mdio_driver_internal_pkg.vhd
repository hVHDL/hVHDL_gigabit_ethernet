library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package mdio_driver_internal_pkg is

    constant MDIO_write_command        : std_logic_vector(5 downto 0) := "110101";
    constant MDIO_write_data_delimiter : std_logic_vector(1 downto 0) := "10";
    constant MDIO_read_command         : std_logic_vector(5 downto 0) := "110110";

    constant mdio_clock_divisor_counter_high : integer := 4;
    constant mdio_transmit_counter_high : integer := (mdio_clock_divisor_counter_high+1)*34;

    type mdio_driver_interface_record is record
        mdio_data_read_is_requested  : boolean;
        mdio_data_write_is_requested : boolean;
        data_to_mdio                 : std_logic_vector(15 downto 0);
        phy_address                  : std_logic_vector(7 downto 0);
        phy_register_address         : std_logic_vector(7 downto 0);
    end record;

    constant init_mdio_driver_interface : mdio_driver_interface_record := (false,false,(others => '0'), (others => '0'), (others => '0'));

    type mdio_driver_record is record
        mdio_clock                      : std_logic;
        MDIO_io_direction_is_out_when_1 : std_logic;
        mdio_clock_counter              : natural range 0 to 15;

        mdio_io_data_out           : std_logic;
        mdio_transmit_register     : std_logic_vector(33 downto 0);
        mdio_write_clock           : natural range 0 to 511;
        mdio_write_is_ready        : boolean;
        mdio_data_write_is_pending : boolean;

        mdio_data_receive_register      : std_logic_vector(15 downto 0);
        mdio_read_clock                 : natural range 0 to 511;
        mdio_read_is_ready              : boolean;
        mdio_data_read_is_pending       : boolean;

        mdio_driver_interface : mdio_driver_interface_record;

    end record; 

    constant init_mdio_driver_record : mdio_driver_record := ('0', '0', 0, '0', (others => '0'), 0, false, false, (others => '0'), 0, false, false , init_mdio_driver_interface);
    alias mdio_transmit_control_init is init_mdio_driver_record;

    alias mdio_transmit_control_group is mdio_driver_record;
--------------------------------------------------
    procedure create_mdio_driver (
        signal self : inout mdio_driver_record;
        mdio_io_in : in std_logic);
------------------------------------------------------------------------
    procedure init_mdio_driver (
        signal mdio_input : out mdio_driver_interface_record);
------------------------------------------------------------------------
    procedure load_data_to_mdio_transmit_shift_register (
        signal self : out mdio_driver_record;
        data : std_logic_vector );
--------------------------------------------------
    function mdio_write_is_ready ( self : mdio_driver_record)
        return boolean;
--------------------------------------------------
    procedure read_data_from_mdio (
        signal self      : out mdio_driver_record;
        phy_address : std_logic_vector(7 downto 0);
        phy_register_address : std_logic_vector(7 downto 0));

    function mdio_read_is_ready ( self : mdio_driver_record)
        return boolean;

    function get_mdio_data ( self : mdio_driver_record)
        return std_logic_vector;
--------------------------------------------------
    procedure write_data_to_mdio (
        signal self      : out mdio_driver_record;
        phy_address      : in std_logic_vector(7 downto 0);
        register_address : in std_logic_vector(7 downto 0);
        data_to_mdio     : in std_logic_vector(15 downto 0));

end package mdio_driver_internal_pkg;

package body mdio_driver_internal_pkg is

--------------------------------------------------
    procedure create_mdio_driver
    (
        signal self : inout mdio_driver_record;
        mdio_io_in : in std_logic
    ) is
    begin
        init_mdio_driver(self.mdio_driver_interface);

        self.mdio_clock_counter <= self.mdio_clock_counter + 1;
        if self.mdio_clock_counter = mdio_clock_divisor_counter_high then 
            self.mdio_clock_counter <= 0;
        end if;

        self.mdio_clock <= '0';
        if self.mdio_clock_counter > mdio_clock_divisor_counter_high/2-1 then
            self.mdio_clock <= '1'; 
        end if; 

        self.mdio_io_data_out <= self.mdio_transmit_register(self.mdio_transmit_register'left);
        if self.mdio_clock_counter = 0 then
            self.mdio_transmit_register <= self.mdio_transmit_register(self.mdio_transmit_register'left-1 downto 0) & '0';

            self.MDIO_io_direction_is_out_when_1 <= '0';
            if self.mdio_read_clock > 90 then 
                self.MDIO_io_direction_is_out_when_1 <= '1';
            end if;

            if self.mdio_write_clock > 1 then 
                self.MDIO_io_direction_is_out_when_1 <= '1';
            end if;
        end if;


        if self.mdio_clock_counter = mdio_clock_divisor_counter_high then
            if self.mdio_read_clock <= 82 AND self.mdio_read_clock > 2 then
                self.mdio_data_receive_register <= self.mdio_data_receive_register(self.mdio_data_receive_register'left-1 downto 0) & mdio_io_in;
            end if;
        end if; 
        if self.mdio_write_clock /= 0 then
            self.mdio_write_clock <= self.mdio_write_clock - 1;
        end if;

        self.mdio_write_is_ready <= false;
        if self.mdio_write_clock = 1 then
            self.mdio_write_is_ready <= true;
        end if;

        if self.mdio_driver_interface.mdio_data_write_is_requested then
            self.mdio_data_write_is_pending <= true;
        end if;
        if (self.mdio_driver_interface.mdio_data_write_is_requested or self.mdio_data_write_is_pending) and self.mdio_clock_counter = 0 then
            self.mdio_data_write_is_pending <= false;
            load_data_to_mdio_transmit_shift_register(self ,
                                MDIO_write_command                          &
                                self.mdio_driver_interface.phy_address(4 downto 0)          &
                                self.mdio_driver_interface.phy_register_address(4 downto 0) &
                                MDIO_write_data_delimiter                   &
                                self.mdio_driver_interface.data_to_mdio(15 downto 0));
            self.mdio_write_clock <= mdio_transmit_counter_high;
            self.MDIO_io_direction_is_out_when_1 <= '1';
        end if;
        if self.mdio_read_clock /= 0 then
            self.mdio_read_clock <= self.mdio_read_clock - 1;
        end if;
        
        self.mdio_read_is_ready <= false;
        if self.mdio_read_clock = 1 then
            self.mdio_read_is_ready <= true;
        end if;

        if self.mdio_driver_interface.mdio_data_read_is_requested then
            self.mdio_data_read_is_pending <= true;
        end if;
        if (self.mdio_driver_interface.mdio_data_read_is_requested or self.mdio_data_read_is_pending) and self.mdio_clock_counter = 0 then
            self.mdio_data_read_is_pending <= false;
            load_data_to_mdio_transmit_shift_register(self ,
                                MDIO_read_command                           &
                                self.mdio_driver_interface.phy_address(4 downto 0)          &
                                self.mdio_driver_interface.phy_register_address(4 downto 0) &
                                MDIO_write_data_delimiter);
            self.mdio_read_clock <= mdio_transmit_counter_high;
            self.MDIO_io_direction_is_out_when_1 <= '1';
        end if;
        
    end create_mdio_driver;
--------------------------------------------------
    procedure load_data_to_mdio_transmit_shift_register
    (
        signal self : out mdio_driver_record;
        data : std_logic_vector
        
    ) is
    begin
        self.mdio_transmit_register(self.mdio_transmit_register'left downto self.mdio_transmit_register'left-data'high) <= data;
        
    end load_data_to_mdio_transmit_shift_register;

--------------------------------------------------
    procedure init_mdio_driver
    (
        signal mdio_input : out mdio_driver_interface_record
    ) is
    begin
        mdio_input.mdio_data_read_is_requested  <= false;
        mdio_input.mdio_data_write_is_requested <= false;
    end init_mdio_driver;

------------------------------------------------------------------------
    procedure read_data_from_mdio
    (
        signal mdio_input : out mdio_driver_interface_record;
        phy_address : std_logic_vector(7 downto 0);
        phy_register_address : std_logic_vector(7 downto 0)
    ) is
    begin
        mdio_input.mdio_data_read_is_requested <= true;
        mdio_input.phy_address                 <= phy_address;
        mdio_input.phy_register_address        <= phy_register_address;
    end read_data_from_mdio;
    
------------------------------------------------------------------------
    procedure write_data_to_mdio
    (
        signal mdio_input : out mdio_driver_interface_record;
        phy_address       : in std_logic_vector(7 downto 0);
        register_address  : in std_logic_vector(7 downto 0);
        data_to_mdio      : in std_logic_vector(15 downto 0)
    ) is
    begin
        assert (unsigned(register_address) < 32) report "invalid address written to mdio " & integer'image(to_integer(unsigned(register_address))) severity failure;
        assert (unsigned(phy_address) < 32) report "invalid phy address written to mdio " & integer'image(to_integer(unsigned(register_address))) severity failure;
        mdio_input.mdio_data_write_is_requested <= true;
        mdio_input.phy_address                  <= phy_address;
        mdio_input.phy_register_address         <= register_address;
        mdio_input.data_to_mdio                 <= data_to_mdio;
    end write_data_to_mdio;

--------------------------------------------------
    procedure write_data_to_mdio
    (
        signal self      : out mdio_driver_record;
        phy_address      : in std_logic_vector(7 downto 0);
        register_address : in std_logic_vector(7 downto 0);
        data_to_mdio     : in std_logic_vector(15 downto 0)
    ) is
    begin
        write_data_to_mdio(self.mdio_driver_interface, phy_address, register_address, data_to_mdio);
        
    end write_data_to_mdio;

--------------------------------------------------
    procedure read_data_from_mdio
    (
        signal self      : out mdio_driver_record;
        phy_address : std_logic_vector(7 downto 0);
        phy_register_address : std_logic_vector(7 downto 0)
    ) is
    begin
        read_data_from_mdio(self.mdio_driver_interface, phy_address, phy_register_address);
    end read_data_from_mdio;

    function mdio_read_is_ready
    (
        self : mdio_driver_record
    )
    return boolean
    is
    begin
        return self.mdio_read_is_ready;
    end mdio_read_is_ready;

    function mdio_write_is_ready
    (
        self : mdio_driver_record
    )
    return boolean
    is
    begin
        return self.mdio_write_is_ready;
    end mdio_write_is_ready;
--------------------------------------------------
    function get_mdio_data
    (
        self : mdio_driver_record
    )
    return std_logic_vector 
    is
    begin
        return self.mdio_data_receive_register;
    end get_mdio_data;
    
--------------------------------------------------
end package body mdio_driver_internal_pkg;
