library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.mdio_three_state_io_driver_pkg.all;

package mdio_driver_internal_pkg is

    constant MDIO_write_command        : std_logic_vector(5 downto 0) := "110101";
    constant MDIO_write_data_delimiter : std_logic_vector(1 downto 0) := "10";
    constant MDIO_read_command         : std_logic_vector(5 downto 0) := "110110";

    constant mdio_clock_divisor_counter_high : integer := 4;
    constant mdio_transmit_counter_high : integer := (mdio_clock_divisor_counter_high+1)*34;

    type mdio_driver_interface is record
        mdio_data_read_is_requested  : boolean;
        mdio_data_write_is_requested : boolean;
        data_to_mdio                 : std_logic_vector(15 downto 0);
        phy_address                  : std_logic_vector(7 downto 0);
        phy_register_address         : std_logic_vector(7 downto 0);
    end record;

    constant init_mdio_driver_interface : mdio_driver_interface := (false,false,(others => '0'), (others => '0'), (others => '0'));

    type mdio_driver_record is record
        mdio_clock                      : std_logic;
        MDIO_io_direction_is_out_when_1 : std_logic;
        mdio_clock_counter              : natural range 0 to 15;

        mdio_transmit_register          : std_logic_vector(33 downto 0);
        mdio_write_clock                : natural range 0 to 511;
        mdio_write_is_ready             : boolean;
        mdio_data_write_is_pending      : boolean;

        mdio_data_receive_register      : std_logic_vector(15 downto 0);
        mdio_read_clock                 : natural range 0 to 511;
        mdio_read_is_ready              : boolean;
        mdio_data_read_is_pending       : boolean;

        mdio_driver_interface : mdio_driver_interface;

    end record; 

    constant mdio_transmit_control_init : mdio_driver_record := ('0', '0', 0, (others => '0'), 0, false, false, (others => '0'), 0, false, false , init_mdio_driver_interface);

    alias mdio_transmit_control_group is mdio_driver_record;
--------------------------------------------------
    procedure generate_mdio_io_waveforms (
        signal mdio_control : inout mdio_driver_record;
        mdio_3_state_data_output : in mdio_three_state_io_driver_data_output_group);
--------------------------------------------------
    procedure load_data_to_mdio_transmit_shift_register (
        signal mdio_control : out mdio_driver_record;
        data : std_logic_vector );
--------------------------------------------------
    procedure write_data_with_mdio (
        signal mdio_control : inout mdio_driver_record);
--------------------------------------------------
    procedure read_data_with_mdio (
        signal mdio_control : inout mdio_driver_record);
--------------------------------------------------

end package mdio_driver_internal_pkg;

package body mdio_driver_internal_pkg is

--------------------------------------------------
    procedure generate_mdio_io_waveforms
    (
        signal mdio_control      : inout mdio_driver_record;
        mdio_3_state_data_output : in mdio_three_state_io_driver_data_output_group
    ) is
    begin

        mdio_control.mdio_clock_counter <= mdio_control.mdio_clock_counter + 1;
        if mdio_control.mdio_clock_counter = mdio_clock_divisor_counter_high then 
            mdio_control.mdio_clock_counter <= 0;
        end if;

        mdio_control.mdio_clock <= '0';
        if mdio_control.mdio_clock_counter > mdio_clock_divisor_counter_high/2-1 then
            mdio_control.mdio_clock <= '1'; 
        end if; 

        if mdio_control.mdio_clock_counter = 0 then
            mdio_control.mdio_transmit_register <= mdio_control.mdio_transmit_register(mdio_control.mdio_transmit_register'left-1 downto 0) & '0';

            mdio_control.MDIO_io_direction_is_out_when_1 <= '0';
            if mdio_control.mdio_read_clock > 90 then 
                mdio_control.MDIO_io_direction_is_out_when_1 <= '1';
            end if;

            if mdio_control.mdio_write_clock > 1 then 
                mdio_control.MDIO_io_direction_is_out_when_1 <= '1';
            end if;
        end if;


        if mdio_control.mdio_clock_counter = mdio_clock_divisor_counter_high then
            if mdio_control.mdio_read_clock <= 82 AND mdio_control.mdio_read_clock > 2 then
                mdio_control.mdio_data_receive_register <= mdio_control.mdio_data_receive_register(mdio_control.mdio_data_receive_register'left-1 downto 0) & mdio_3_state_data_output.io_input_data;
            end if;
        end if; 
    end generate_mdio_io_waveforms;

--------------------------------------------------
    procedure load_data_to_mdio_transmit_shift_register
    (
        signal mdio_control : out mdio_driver_record;
        data : std_logic_vector
        
    ) is
    begin
        mdio_control.mdio_transmit_register(mdio_control.mdio_transmit_register'left downto mdio_control.mdio_transmit_register'left-data'high) <= data;
        
    end load_data_to_mdio_transmit_shift_register;

--------------------------------------------------
    procedure write_data_with_mdio
    (
        signal mdio_control : inout mdio_driver_record
    ) is
        alias mdio_input is mdio_control.mdio_driver_interface;
    begin

        if mdio_control.mdio_write_clock /= 0 then
            mdio_control.mdio_write_clock <= mdio_control.mdio_write_clock - 1;
        end if;

        mdio_control.mdio_write_is_ready <= false;
        if mdio_control.mdio_write_clock = 1 then
            mdio_control.mdio_write_is_ready <= true;
        end if;

        if mdio_input.mdio_data_write_is_requested then
            mdio_control.mdio_data_write_is_pending <= true;
        end if;
        if (mdio_input.mdio_data_write_is_requested or mdio_control.mdio_data_write_is_pending) and mdio_control.mdio_clock_counter = 0 then
            mdio_control.mdio_data_write_is_pending <= false;
            load_data_to_mdio_transmit_shift_register(mdio_control ,
                                MDIO_write_command                          &
                                mdio_input.phy_address(4 downto 0)          &
                                mdio_input.phy_register_address(4 downto 0) &
                                MDIO_write_data_delimiter                   &
                                mdio_input.data_to_mdio(15 downto 0));
            mdio_control.mdio_write_clock <= mdio_transmit_counter_high;
            mdio_control.MDIO_io_direction_is_out_when_1 <= '1';
        end if;

    end write_data_with_mdio;
--------------------------------------------------
    procedure read_data_with_mdio
    (
        signal mdio_control : inout mdio_driver_record
    ) is
        alias mdio_input is mdio_control.mdio_driver_interface;
    begin

        if mdio_control.mdio_read_clock /= 0 then
            mdio_control.mdio_read_clock <= mdio_control.mdio_read_clock - 1;
        end if;
        
        mdio_control.mdio_read_is_ready <= false;
        if mdio_control.mdio_read_clock = 1 then
            mdio_control.mdio_read_is_ready <= true;
        end if;

        if mdio_input.mdio_data_read_is_requested then
            mdio_control.mdio_data_read_is_pending <= true;
        end if;
        if (mdio_input.mdio_data_read_is_requested or mdio_control.mdio_data_read_is_pending) and mdio_control.mdio_clock_counter = 0 then
            mdio_control.mdio_data_read_is_pending <= false;
            load_data_to_mdio_transmit_shift_register(mdio_control ,
                                MDIO_read_command                           &
                                mdio_input.phy_address(4 downto 0)          &
                                mdio_input.phy_register_address(4 downto 0) &
                                MDIO_write_data_delimiter);
            mdio_control.mdio_read_clock <= mdio_transmit_counter_high;
            mdio_control.MDIO_io_direction_is_out_when_1 <= '1';
        end if;
        
    end read_data_with_mdio;

------------------------------------------------------------------------
    procedure init_mdio_driver
    (
        signal mdio_input : out mdio_driver_interface
    ) is
    begin
        mdio_input.mdio_data_read_is_requested  <= false;
        mdio_input.mdio_data_write_is_requested <= false;
    end init_mdio_driver;

------------------------------------------------------------------------
    procedure read_data_from_mdio
    (
        signal mdio_input : out mdio_driver_interface;
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
        signal mdio_input : out mdio_driver_interface;
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
end package body mdio_driver_internal_pkg;
