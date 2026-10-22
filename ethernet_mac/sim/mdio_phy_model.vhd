library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- Behavioural clause 22 MDIO slave with 32 plain registers. Requires the full preamble,
-- answers only to g_phy_address and drives read data g_output_delay after MDC rises.
-- a rising reset_registers puts the registers back to their defaults before the next frame, link
-- is returned in bit 2 of register 1.
entity mdio_phy_model is
    generic(
        g_phy_address  : natural := 0;
        g_output_delay : time := 100 ns
    );
    port(
        mdc  : in std_logic;
        mdio : inout std_logic;
        reset_registers : in boolean := false;
        link            : in boolean := false
    );
end entity mdio_phy_model;

architecture behavioural of mdio_phy_model is
begin

    model : process
        type register_array is array (0 to 31) of std_logic_vector(15 downto 0);
        constant defaults  : register_array := (2 => x"D565", 3 => x"A401", 16#17# => x"B000", others => x"0000");
        variable registers : register_array := defaults;
        variable was_reset : boolean := false;
        variable ones   : natural := 0;
        variable header : std_logic_vector(13 downto 0);
        variable data   : std_logic_vector(15 downto 0);
        variable phy, reg : natural;

        procedure next_bit(b : out std_logic) is
        begin
            wait until rising_edge(mdc);
            b := to_x01(mdio);
        end procedure;

        variable b : std_logic;
    begin
        mdio <= 'Z';
        -- preamble of at least 32 ones followed by start 01
        ones := 0;
        loop
            next_bit(b);
            exit when b = '0' and ones >= 32;
            if b = '1' then ones := ones + 1; else ones := 0; end if;
        end loop;
        header(13) := '0';
        for i in 12 downto 0 loop
            next_bit(b); header(i) := b;
        end loop;
        assert header(13 downto 12) = "01" report "mdio model: bad start" severity error;
        if reset_registers and not was_reset then
            registers := defaults;
        end if;
        was_reset := reset_registers;
        registers(1)(2) := '1' when link else '0';
        phy := to_integer(unsigned(header(9 downto 5)));
        reg := to_integer(unsigned(header(4 downto 0)));

        if header(11 downto 10) = "10" then
            -- read: turnaround, then 16 data bits
            next_bit(b);  -- TA first bit, master releases
            if phy = g_phy_address then
                mdio <= '0' after g_output_delay;
                data := registers(reg);
                for i in 15 downto 0 loop
                    wait until rising_edge(mdc);
                    mdio <= data(i) after g_output_delay;
                end loop;
                wait until rising_edge(mdc);
                mdio <= 'Z' after g_output_delay;
            end if;
        elsif header(11 downto 10) = "01" then
            next_bit(b); next_bit(b);  -- TA 10
            for i in 15 downto 0 loop
                next_bit(b); data(i) := b;
            end loop;
            if phy = g_phy_address then
                registers(reg) := data;
            end if;
        else
            report "mdio model: bad opcode" severity error;
        end if;
    end process model;

end architecture behavioural;
