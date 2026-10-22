library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.mdio_pkg.all;

-- Clause 22 MDIO master. MDC = clock / (2*g_clocks_per_half_mdc).
-- MDIO is changed on the falling MDC edge and read data is sampled at the end of the
-- MDC low phase, which leaves the PHY a full MDC period for its output delay.
-- frame: 32 x '1' preamble, ST 01, OP (10 read, 01 write), PHYAD, REGAD, TA, 16 data bits
entity mdio_driver is
    generic(
        g_clocks_per_half_mdc : positive := 24   -- 2.5 MHz MDC at 120 MHz
    );
    port(
        clock        : in std_logic;
        mdio_in      : in mdio_in_record;
        mdio_out     : out mdio_out_record;
        fpga_out     : out mdio_fpga_out_record;
        fpga_mdio_in : in std_logic
    );
end entity mdio_driver;

architecture rtl of mdio_driver is

    constant frame_length : natural := 64;
    constant turnaround_bit : natural := 46; -- first bit after ST, OP, PHYAD and REGAD

    signal clock_counter : natural range 0 to 2*g_clocks_per_half_mdc-1 := 0;
    signal bit_counter   : natural range 0 to frame_length := 0;
    signal is_active     : boolean := false;
    signal is_read       : boolean := false;

    signal shift_register : std_logic_vector(frame_length-1 downto 0) := (others => '1');
    signal receive_register : std_logic_vector(15 downto 0) := (others => '0');
    signal mdio_sync : std_logic_vector(1 downto 0) := (others => '1');

    signal mdc      : std_logic := '0';
    signal mdio_oe  : std_logic := '0';
    signal ready    : boolean := true;
    signal done     : boolean := false;

    function opcode(read_transaction : boolean) return std_logic_vector is
    begin
        if read_transaction then return "10"; else return "01"; end if;
    end function;

begin

    mdio_out <= (is_ready => ready, transaction_is_done => done, read_data => receive_register);
    fpga_out <= (mdc => mdc, mdio_out => shift_register(shift_register'left), mdio_oe => mdio_oe);

    driver : process(clock)
    begin
        if rising_edge(clock) then
            mdio_sync <= mdio_sync(0) & to_x01(fpga_mdio_in);
            done      <= false;

            if not is_active then
                mdc <= '0';
                if mdio_in.command /= none then
                    shift_register <= (31 downto 0 => '1')
                                      & "01" & opcode(mdio_in.command = read)
                                      & std_logic_vector(to_unsigned(mdio_in.phy_address, 5))
                                      & std_logic_vector(to_unsigned(mdio_in.register_address, 5))
                                      & "10" & mdio_in.write_data;
                    is_read       <= mdio_in.command = read;
                    is_active     <= true;
                    ready         <= false;
                    mdio_oe       <= '1';
                    bit_counter   <= 0;
                    clock_counter <= 0;
                end if;
            else
                if clock_counter < 2*g_clocks_per_half_mdc-1 then
                    clock_counter <= clock_counter + 1;
                else
                    clock_counter <= 0;
                end if;

                -- MDC low during the first half of a bit, high during the second
                if clock_counter = g_clocks_per_half_mdc-1 then
                    mdc <= '1';
                    -- sample at the end of the low phase, read data bits are 48..63
                    if is_read and bit_counter >= turnaround_bit + 2 then
                        receive_register <= receive_register(14 downto 0) & mdio_sync(1);
                    end if;
                end if;

                if clock_counter = 2*g_clocks_per_half_mdc-1 then
                    mdc <= '0';
                    shift_register <= shift_register(shift_register'left-1 downto 0) & '1';
                    bit_counter    <= bit_counter + 1;
                    if is_read and bit_counter + 1 = turnaround_bit then
                        mdio_oe <= '0';
                    end if;
                    if bit_counter + 1 = frame_length then
                        is_active <= false;
                        mdio_oe   <= '0';
                        ready     <= true;
                        done      <= true;
                    end if;
                end if;
            end if;
        end if;
    end process driver;

end architecture rtl;
