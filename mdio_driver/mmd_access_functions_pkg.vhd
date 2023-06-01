library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.mdio_driver_pkg.all;

package mmd_access_functions_pkg is

    type mmd_access_record is record
        mmd_read_process_counter : natural range 0 to 7;
        mmd_write_process_counter : natural range 0 to 7;
        mmd_write_is_ready : boolean;
        mmd_read_is_ready : boolean;
    end record;

    constant mmd_init : mmd_access_record := (0,0,false,false);

    procedure read_data_from_mmd (
        signal mdio_driver_input : out mdio_driver_data_input_group;
        mdio_driver_output       : in mdio_driver_data_output_group;
        phy_address              : std_logic_vector(7 downto 0);
        mmd_register_address     : std_logic_vector(7 downto 0);
        signal data_from_mmd     : out std_logic_vector(15 downto 0);
        signal counter           : inout natural);


    procedure write_data_to_mmd (
        signal mdio_driver_input : inout mdio_driver_data_input_group;
        mdio_driver_output       : in mdio_driver_data_output_group;
        phy_address              : std_logic_vector(7 downto 0);
        mmd_register_address     : std_logic_vector(7 downto 0);
        signal data_to_mmd       : out std_logic_vector(15 downto 0);
        signal counter           : inout natural);

end package mmd_access_functions_pkg;


package body mmd_access_functions_pkg is

        constant mmd_access_control_register : std_logic_vector := x"0d";
        constant mmd_access_data_register : std_logic_vector := x"0e";

        ------------------------------------------------------------------------
        procedure read_data_from_mmd
        (
            signal mdio_driver_input : out mdio_driver_data_input_group;
            mdio_driver_output : in mdio_driver_data_output_group;
            phy_address : std_logic_vector(7 downto 0);
            mmd_register_address : std_logic_vector(7 downto 0);
            signal data_from_mmd : out std_logic_vector(15 downto 0);
            signal counter : inout natural
        ) is
            variable mmd_access_data : std_logic_vector(15 downto 0) := (others => '0');
        begin 
            CASE counter is
                WHEN 0 => 
                    mmd_access_data(4 downto 0) := mmd_register_address(4 downto 0);
                    write_data_to_mdio(mdio_driver_input, phy_address, mmd_access_control_register, mmd_access_data);
                    counter <= counter + 1;
                WHEN 1 =>
                    if mdio_data_write_is_ready(mdio_driver_output) then
                        read_data_from_mdio(mdio_driver_input, phy_address, mmd_access_data_register);
                        counter <= counter + 1;
                    end if;
                WHEN 2 =>
                    if mdio_data_read_is_ready(mdio_driver_output) then
                        data_from_mmd <= get_data_from_mdio(mdio_driver_output);
                        counter <= counter + 1;
                    end if; 
                WHEN others =>
            end CASE; 
        end read_data_from_mmd;
        ------------------------------------------------------------------------
        procedure write_data_to_mmd
        (
            signal mdio_driver_input : inout mdio_driver_data_input_group;
            mdio_driver_output : in mdio_driver_data_output_group;
            phy_address : std_logic_vector(7 downto 0);
            mmd_register_address : std_logic_vector(7 downto 0);
            signal data_to_mmd       : out std_logic_vector(15 downto 0);
            signal counter : inout natural
        ) is
            variable mmd_access_data : std_logic_vector(15 downto 0) := (others => '0');
        begin 
            CASE counter is
                WHEN 0 => 
                    mmd_access_data(4 downto 0) := mmd_register_address(4 downto 0);
                    mmd_access_data(15 downto 14) := "01";
                    write_data_to_mdio(mdio_driver_input, phy_address, mmd_access_control_register, mmd_access_data);
                    counter <= counter + 1;
                WHEN 1 =>
                    if mdio_data_write_is_ready(mdio_driver_output) then
                        write_data_to_mdio(mdio_driver_input, phy_address, mmd_access_control_register, mmd_access_data);
                        counter <= counter + 1;
                    end if;
                WHEN 2 =>
                    if mdio_data_write_is_ready(mdio_driver_output) then
                        write_data_to_mdio(mdio_driver_input, phy_address, mmd_access_control_register, mmd_access_data);
                        counter <= counter + 1;
                    end if;
                WHEN others =>
            end CASE; 
        end write_data_to_mmd;

end package body mmd_access_functions_pkg;

