LIBRARY ieee  ; 
LIBRARY std  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.std_logic_textio.all  ; 
    use ieee.math_real.all;
    USE std.textio.all  ; 

library work;
    use work.mdio_driver_pkg.all;
    use work.mmd_access_functions_pkg.all;

entity tb_mdio_driver is
end;

architecture sim of tb_mdio_driver is
    signal rstn : std_logic;

    signal simulation_running  : boolean;
    signal simulator_clock     : std_logic :='0';
    signal clocked_reset       : std_logic;
    constant clock_per         : time       := 1 ns;
    constant clock_half_per    : time       := 0.5 ns;
    constant simtime_in_clocks : integer    := 1000;

    signal mdio_driver_clocks   : mdio_driver_clock_group;
    signal mdio_driver_FPGA_out : mdio_driver_FPGA_output_group;
    signal mdio_driver_FPGA_inout  : mdio_driver_FPGA_three_state_record;
    signal mdio_driver_data_in  : mdio_driver_data_input_group;
    signal mdio_driver_data_out : mdio_driver_data_output_group;

    signal simulator_counter          : natural := 0;

    signal mdio_receive_shift_register  : std_logic_vector(33 downto 0) := (others => '0');
    signal mdio_clock_buffer : std_logic;

    signal mdio_clock : std_logic;
    signal mdio_write_is_ready : boolean;
    signal mdio_read_is_ready : boolean;
    signal counter_to_mdio_read_trigger : natural := 0;
    signal MDIO_io_direction_is_out_when_1 : std_logic;
    signal data_from_mdio : std_logic_vector(15 downto 0);

    signal mdio_three_state_io : std_logic;
    signal data_fetched_from_mmd : std_logic_vector(15 downto 0) := (others => '0');
    signal mmd_read_process_counter : natural range 0 to 7 := 7;
    signal mmd_write_process_counter : natural range 0 to 7 := 7;


begin

------------------------------------------------------------------------
    simtime : process
    begin
        simulation_running <= true;
        wait for simtime_in_clocks*clock_per;
        simulation_running <= false;
        wait;
    end process simtime;	

------------------------------------------------------------------------
    sim_clock_gen : process
    begin
        report " ";
        report "*************************";
        report "**  ethernet MDIO test **";
        report "*************************";
        report " ";
        simulator_clock <= '0';
        rstn <= '0';
        simulator_clock <= '0';
        wait for clock_half_per;
        while simulation_running loop
            wait for clock_half_per;
                rstn <= '1';
                simulator_clock <= not simulator_clock;
            end loop;
        wait;
    end process;
------------------------------------------------------------------------

    clocked_reset_generator : process(simulator_clock, rstn)
    begin
        if rstn = '0' then
        -- reset state
            clocked_reset <= '0';
    
        elsif rising_edge(simulator_clock) then
            clocked_reset <= '1';
    
        end if; -- rstn
    end process clocked_reset_generator;	

------------------------------------------------------------------------
    test_mdio_driver : process(simulator_clock,mdio_driver_FPGA_out.mdio_clock) 


    begin
        if rising_edge(simulator_clock) then

            simulator_counter <= simulator_counter + 1;

            init_mdio_driver(mdio_driver_data_in);

            read_data_from_mmd(mdio_driver_data_in, mdio_driver_data_out, x"00", x"01", data_fetched_from_mmd, mmd_read_process_counter);
            write_data_to_mmd(mdio_driver_data_in, mdio_driver_data_out, x"00", x"01", data_fetched_from_mmd, mmd_write_process_counter);

            if simulator_counter = 3 then
                mmd_read_process_counter <= 0;
            end if;

            -- mmd_read : 
            -- 1. 
            -- if simulator_counter = 180 then
            --     read_data_from_mdio(mdio_driver_data_in, x"1f", x"1f");
            -- end if;

            -- if mdio_data_write_is_ready(mdio_driver_data_out) then
            --     assert mdio_receive_shift_register = "11" & x"5ffeacdc" report " write data failed " severity failure;
            --     report " ";
            --     report "mdio write successful!";
            --     report " ";
            --     read_data_from_mdio(mdio_driver_data_in, x"1f", x"1f");
            -- end if;
            --
            -- if mdio_data_read_is_ready(mdio_driver_data_out) then
            --     assert mdio_receive_shift_register = "11" & x"6ffe0000" report " read unsuccessful " severity failure;
            --     report " ";
            --     report "mdio read successful!";
            --     report " ";
            -- end if;

        end if; --rising_edge

        -- if falling_edge(mdio_driver_FPGA_out.mdio_clock) then
        --     mdio_receive_shift_register <= mdio_receive_shift_register(mdio_receive_shift_register'left-1 downto 0) & mdio_driver_FPGA_out.MDIO_serial_data_out;
        -- end if;
        --
    end process test_mdio_driver;	

    mdio_clock <= mdio_driver_FPGA_out.mdio_clock;
    
    mdio_driver_clocks <= (clock => simulator_clock);
    mdio_write_is_ready <= mdio_driver_data_out.mdio_write_is_ready;
    mdio_read_is_ready <= mdio_driver_data_out.mdio_read_is_ready;
    MDIO_io_direction_is_out_when_1 <= mdio_driver_data_out.mdio_read_when_1;

    data_from_mdio <= mdio_driver_data_out.data_from_mdio;
    mdio_three_state_io <= mdio_driver_FPGA_inout.mdio_three_state_io_driver_FPGA_inout.MDIO_inout_data;

    u_mdio_driver : mdio_driver
    port map(
        mdio_driver_clocks   ,
        mdio_driver_FPGA_out ,
        mdio_driver_FPGA_inout ,
        mdio_driver_data_in  ,
        mdio_driver_data_out);

------------------------------------------------------------------------
end sim;
