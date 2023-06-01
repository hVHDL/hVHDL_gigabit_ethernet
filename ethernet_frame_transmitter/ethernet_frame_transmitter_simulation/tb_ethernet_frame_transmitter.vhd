LIBRARY ieee  ; 
LIBRARY std  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.std_logic_textio.all  ; 
    use ieee.math_real.all;
    USE std.textio.all  ; 

library work;
    use work.ethernet_clocks_pkg.all;
    use work.PCK_CRC32_D8.all;
    use work.ethernet_frame_transmit_controller_pkg.all;

entity tb_ethernet_frame_transmitter is
end;

architecture sim of tb_ethernet_frame_transmitter is
    signal rstn : std_logic;

    signal simulation_running : boolean;
    signal simulator_clock : std_logic;
    signal clocked_reset : std_logic;
    constant clock_per : time := 1 ns;
    constant clock_half_per : time := 0.5 ns;
    constant simtime_in_clocks : integer := 150;
    signal simulator_counter : natural := 0; 

------------------------------------------------------------------------
    alias core_clock is simulator_clock;
    alias reset_n is clocked_reset;
    signal ethernet_clocks   : ethernet_clock_group;
    signal transmitted_byte : std_logic_vector(7 downto 0); 

    signal fcs   : std_logic_vector(31 downto 0);
    signal crc32 : std_logic_vector(31 downto 0);

    signal frame_transmit_controller : frame_transmitter_record := init_transmit_controller;
    signal counter : natural;

------------------------------------------------------------------------
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
    frame_transmitter_starter : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            if clocked_reset = '0' then
                simulator_counter <= 0;
            else
                simulator_counter <= simulator_counter + 1;
                create_transmit_controller(frame_transmit_controller);
                if simulator_counter = 10 then
                    transmit_ethernet_frame(frame_transmit_controller, 27);
                end if; 

            end if; -- rstn
        end if; --rising_edge
    end process frame_transmitter_starter;	

    transmitted_byte <= frame_transmit_controller.byte; 

    fcs  <= frame_transmit_controller.fcs;
    crc32 <= frame_transmit_controller.fcs_shift_register;
    counter <=  frame_transmit_controller.byte_counter;
------------------------------------------------------------------------
------------------------------------------------------------------------
    -- ethernet_ddio   <= ethernet_frame_transmitter_FPGA_out.ethernet_tx_ddio_FPGA_out.ethernet_tx_ddio_FPGA_io;
    -- ethernet_clocks <= (core_clock, reset_n,
    --                    tx_ddr_clocks =>(core_clock, reset_n),
    --                    rx_ddr_clocks =>(core_clock, reset_n));
    --
    -- --------------------------------------------------
    -- u_ethernet_frame_transmitter : ethernet_frame_transmitter
    -- port map( ethernet_clocks,
    -- 	  ethernet_frame_transmitter_FPGA_out,
    -- 	  ethernet_frame_transmitter_data_in,
    -- 	  ethernet_frame_transmitter_data_out);
------------------------------------------------------------------------
end sim;
