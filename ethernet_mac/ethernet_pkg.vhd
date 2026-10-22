library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- Ethernet frame constants, CRC-32 and the RGMII DDIO record types.
package ethernet_pkg is

    subtype byte is std_logic_vector(7 downto 0);

    constant preamble_byte        : byte := x"55";
    constant start_of_frame_byte  : byte := x"D5";
    constant crc32_init           : std_logic_vector(31 downto 0) := x"FFFFFFFF";
    -- crc register value after running the crc over a frame including its FCS
    constant crc32_residue        : std_logic_vector(31 downto 0) := x"DEBB20E3";
    constant test_frame_ethertype : std_logic_vector(15 downto 0) := x"88B5"; -- local experimental

    -- reflected CRC-32 (IEEE 802.3), data bit 0 first
    function next_crc32 ( crc : std_logic_vector(31 downto 0); data : byte)
        return std_logic_vector;

    -- frame check sequence byte n (0 first on the wire) of a crc register
    function fcs_byte ( crc : std_logic_vector(31 downto 0); n : natural)
        return byte;

    -- RGMII pins as seen through DDIO registers: bit 4 is CTL, bits 3:0 data.
    -- hi is the rising edge half (TXD/RXD = data(3:0), CTL = EN/DV),
    -- lo the falling edge half (data(7:4), CTL = EN xor ER).
    type rgmii_ddio_record is record
        hi : std_logic_vector(4 downto 0);
        lo : std_logic_vector(4 downto 0);
    end record;

    constant rgmii_idle : rgmii_ddio_record := ((others => '0'), (others => '0'));

    -- byte stream with GMII style valid
    type gmii_record is record
        data     : byte;
        is_valid : boolean;
        is_error : boolean;
    end record;

    constant gmii_idle : gmii_record := ((others => '0'), false, false);
    type gmii_record_array is array (natural range <>) of gmii_record;

    -- pins of the ethernet entity, apart from the receive clock which is its own port
    type ethernet_fpga_in_record is record
        rgmii_rx      : rgmii_ddio_record;  -- from DDIO input registers clocked by the rx clock
        rx_pll_locked : std_logic;
        mdio_in       : std_logic;
    end record;

    type ethernet_fpga_out_record is record
        rgmii_tx       : rgmii_ddio_record;  -- to DDIO output registers clocked by the system clock
        tx_clock       : rgmii_ddio_record;  -- TX_CLK through a DDIO output, bit 0 used
        mdc            : std_logic;
        mdio_out       : std_logic;
        mdio_oe        : std_logic;
        rx_pll_reset_n : std_logic;
    end record;

end package ethernet_pkg;

package body ethernet_pkg is

    function next_crc32
    (
        crc : std_logic_vector(31 downto 0);
        data : byte
    )
    return std_logic_vector
    is
        variable c : std_logic_vector(31 downto 0) := crc;
    begin
        for i in 0 to 7 loop
            if (c(0) xor data(i)) = '1' then
                c := ('0' & c(31 downto 1)) xor x"EDB88320";
            else
                c := '0' & c(31 downto 1);
            end if;
        end loop;
        return c;
    end next_crc32;

    function fcs_byte
    (
        crc : std_logic_vector(31 downto 0);
        n   : natural
    )
    return byte
    is
        variable fcs : std_logic_vector(31 downto 0);
    begin
        fcs := not crc;
        return fcs(8*n+7 downto 8*n);
    end fcs_byte;

end package body ethernet_pkg;
