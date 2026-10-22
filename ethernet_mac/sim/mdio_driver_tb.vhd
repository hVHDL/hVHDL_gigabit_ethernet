LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.mdio_pkg.all;

entity mdio_driver_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of mdio_driver_tb is

    constant clock_period : time := 8.333 ns;
    constant phy_address  : natural := 5;

    signal clock    : std_logic := '0';
    signal mdio_in  : mdio_in_record := init_mdio_in;
    signal mdio_out : mdio_out_record;
    signal fpga_out : mdio_fpga_out_record;
    signal mdio     : std_logic;

begin

    clock <= not clock after clock_period/2;

    u_driver : entity work.mdio_driver
    port map(clock, mdio_in, mdio_out, fpga_out, mdio);

    mdio <= fpga_out.mdio_out when fpga_out.mdio_oe = '1' else 'H';  -- board pull-up

    u_phy : entity work.mdio_phy_model
    generic map(g_phy_address => phy_address, g_output_delay => 300 ns)
    port map(fpga_out.mdc, mdio);

    main : process

        procedure run(command : mdio_command; phy, reg : natural; data : std_logic_vector(15 downto 0) := x"0000") is
        begin
            wait until rising_edge(clock) and mdio_is_ready(mdio_out);
            if command = read then
                request_mdio_read(mdio_in, phy, reg);
            else
                request_mdio_write(mdio_in, phy, reg, data);
            end if;
            wait until rising_edge(clock);
            init_mdio(mdio_in);
            wait until rising_edge(clock) and mdio_transaction_is_done(mdio_out);
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("read_phy_identifier") then
                run(read, phy_address, phy_identifier_1);
                check_equal(get_mdio_read_data(mdio_out), std_logic_vector'(x"D565"), "PHYID1");
                run(read, phy_address, phy_identifier_2);
                check_equal(get_mdio_read_data(mdio_out), std_logic_vector'(x"A401"), "PHYID2");

            elsif run("write_and_read_register") then
                run(write, phy_address, 23, x"1234");
                run(read, phy_address, 23);
                check_equal(get_mdio_read_data(mdio_out), std_logic_vector'(x"1234"), "register 23");

            elsif run("other_phy_address_reads_pull_up") then
                run(read, phy_address + 1, phy_identifier_1);
                check_equal(get_mdio_read_data(mdio_out), std_logic_vector'(x"FFFF"), "no phy");
            end if;
        end loop;

        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

end vunit_simulation;
