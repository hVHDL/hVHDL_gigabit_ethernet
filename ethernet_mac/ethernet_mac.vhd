library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;
    use work.mdio_pkg.all;

-- A gigabit Ethernet MAC on RGMII with 8 bit AXI streams, in place of Efinix's Triple Speed
-- Ethernet MAC: its registers that the Zephyr drivers (eth_efinix_tsemac.c,
-- mdio_efinix_tsemac.c) use, at its offsets, on an APB3 slave.
--
--   transmit  s_t* (clock) -> ethernet_mac_tx -> rgmii_tx
--   receive   rgmii_rx -> ethernet_mac_rx (rx_clock) -> m_t*, the FCS stripped
--   MDIO      mdio_driver, MDC = clock / (2*g_clocks_per_half_mdc)
-- 1000 Mb/s full duplex only: the speed bits are kept but change nothing, and there is no
-- pause frame or half duplex logic.
--
-- registers, byte offsets, zero wait states
--   0x008 RW COMMAND_CONFIG  bit0 TX_ENA, bit1 RX_ENA, bit4 PROMIS_EN; the other bits kept
--   0x00c RW MAC_ADDR_LO     address bytes 0..3 (byte 0, first on the wire, in bits 7:0)
--   0x010 RW MAC_ADDR_HI     bytes 4..5 in bits 15:0
--   0x068 R  frames transmitted
--   0x06c R  frames received (handed to the stream)
--   0x070 R  frames received with a CRC error or RX_ER
--   0x088 R  frames received too short, too long or with the FIFO full
--   0x08c R  frames to transmit cut short (the stream ran dry)
--   0x100 RW MDIO_DIVIDER    kept, MDC is set by the generic
--   0x104 W  MDIO_RD_WR_EN   bit0 a read, bit1 a write of MDIO_REG_PHY's register
--   0x108 RW MDIO_REG_PHY    bits 4:0 the register, bits 12:8 the PHY address
--   0x10c RW MDIO_WR_DATA    bits 15:0
--   0x110 R  MDIO_RD_DATA    bits 15:0, of the last read
--   0x114 R  MDIO_STATUS     bit1 busy
--   0x144 RW MAC_ADDR_MASK_LO, 0x148 MAC_ADDR_MASK_HI  the address bits compared, as the address
-- Other addresses read 0, writes to them are ignored. reset clears the registers and counters.
entity ethernet_mac is
    generic(
        g_rx_fifo_depth       : positive := 4096;
        g_clocks_per_half_mdc : positive := 25     -- 2.5 MHz MDC at 125 MHz
    );
    port(
        clock        : in std_logic;   -- 125 MHz: the registers, the transmit side and RGMII transmit
        reset        : in std_logic;   -- synchronous, active high
        paddr        : in std_logic_vector(8 downto 0);
        psel         : in std_logic;
        penable      : in std_logic;
        pwrite       : in std_logic;
        pwdata       : in std_logic_vector(31 downto 0);
        pready       : out std_logic;
        prdata       : out std_logic_vector(31 downto 0);
        pslverror    : out std_logic;

        s_tvalid     : in std_logic;
        s_tready     : out std_logic;
        s_tdata      : in std_logic_vector(7 downto 0);
        s_tlast      : in std_logic;

        rx_clock     : in std_logic;   -- from the PLL on RX_CLK
        rx_reset     : in std_logic := '0';  -- any clock: empties the receive FIFO while high
        m_tvalid     : out std_logic;
        m_tready     : in std_logic;
        m_tdata      : out std_logic_vector(7 downto 0);
        m_tlast      : out std_logic;

        rgmii_rx_in  : in rgmii_ddio_record;   -- DDIO input registers on rx_clock
        rgmii_tx_out : out rgmii_ddio_record;  -- DDIO output registers on clock
        tx_clock_out : out rgmii_ddio_record;  -- TX_CLK's DDIO output, bit 0

        mdc          : out std_logic;
        mdio_out     : out std_logic;
        mdio_oe      : out std_logic;
        mdio_in      : in std_logic
    );
end entity ethernet_mac;

architecture rtl of ethernet_mac is

    -- registers
    signal command_config : std_logic_vector(31 downto 0) := (others => '0');
    signal mac_address    : std_logic_vector(47 downto 0) := (others => '0');
    signal address_mask   : std_logic_vector(47 downto 0) := (others => '0');
    signal mdio_divider   : std_logic_vector(7 downto 0) := (others => '0');
    signal mdio_reg_phy   : std_logic_vector(12 downto 0) := (others => '0');
    signal mdio_wr_data   : std_logic_vector(15 downto 0) := (others => '0');
    signal mdio_rd_data   : std_logic_vector(15 downto 0) := (others => '0');
    signal mdio_busy      : boolean := false;

    subtype counter is unsigned(31 downto 0);
    signal frames_tx_ok, frames_rx_ok, crc_errors, in_errors, out_errors : counter := (others => '0');

    -- the configuration in the receive clock
    constant config_width : natural := 2 + 48 + 48;
    signal config, rx_config : std_logic_vector(config_width-1 downto 0);
    signal rx_reset_sync : std_logic_vector(1 downto 0) := (others => '1');
    attribute async_reg : boolean;
    attribute async_reg of rx_reset_sync : signal is true;

    signal tx_gmii, rx_gmii : gmii_record;
    signal rx_frame_is_ended : boolean;
    signal rx_received, rx_crc_error, rx_frame_error : boolean;
    signal received, crc_error, frame_error : boolean;
    signal frame_sent, tx_frame_error : boolean;

    signal mdio_request  : mdio_in_record := init_mdio_in;
    signal mdio_response : mdio_out_record;
    signal mdio_pins     : mdio_fpga_out_record;

    function register_at(address : std_logic_vector(8 downto 0)) return natural is
    begin
        return to_integer(unsigned(address));
    end function;

begin

    pready    <= '1';
    pslverror <= '0';

    read_mux : process(all)
    begin
        prdata <= (others => '0');
        CASE register_at(paddr) is
            WHEN 16#008# => prdata <= command_config;
            WHEN 16#00c# => prdata <= mac_address(31 downto 0);
            WHEN 16#010# => prdata(15 downto 0) <= mac_address(47 downto 32);
            WHEN 16#068# => prdata <= std_logic_vector(frames_tx_ok);
            WHEN 16#06c# => prdata <= std_logic_vector(frames_rx_ok);
            WHEN 16#070# => prdata <= std_logic_vector(crc_errors);
            WHEN 16#088# => prdata <= std_logic_vector(in_errors);
            WHEN 16#08c# => prdata <= std_logic_vector(out_errors);
            WHEN 16#100# => prdata(7 downto 0) <= mdio_divider;
            WHEN 16#108# => prdata(12 downto 0) <= mdio_reg_phy;
            WHEN 16#10c# => prdata(15 downto 0) <= mdio_wr_data;
            WHEN 16#110# => prdata(15 downto 0) <= mdio_rd_data;
            WHEN 16#114# => if mdio_busy then prdata(1) <= '1'; end if;
            WHEN 16#144# => prdata <= address_mask(31 downto 0);
            WHEN 16#148# => prdata(15 downto 0) <= address_mask(47 downto 32);
            WHEN others  => null;
        end CASE;
    end process;

    registers : process(clock)
        variable data : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clock) then
            init_mdio(mdio_request);
            data := pwdata;

            if psel = '1' and penable = '1' and pwrite = '1' then
                CASE register_at(paddr) is
                    WHEN 16#008# => command_config <= data;
                    WHEN 16#00c# => mac_address(31 downto 0) <= data;
                    WHEN 16#010# => mac_address(47 downto 32) <= data(15 downto 0);
                    WHEN 16#100# => mdio_divider <= data(7 downto 0);
                    WHEN 16#104# =>
                        if not mdio_busy and mdio_is_ready(mdio_response) then
                            if data(0) = '1' then
                                request_mdio_read(mdio_request
                                    , to_integer(unsigned(mdio_reg_phy(12 downto 8)))
                                    , to_integer(unsigned(mdio_reg_phy(4 downto 0))));
                                mdio_busy <= true;
                            elsif data(1) = '1' then
                                request_mdio_write(mdio_request
                                    , to_integer(unsigned(mdio_reg_phy(12 downto 8)))
                                    , to_integer(unsigned(mdio_reg_phy(4 downto 0)))
                                    , mdio_wr_data);
                                mdio_busy <= true;
                            end if;
                        end if;
                    WHEN 16#108# => mdio_reg_phy <= data(12 downto 8) & "000" & data(4 downto 0);
                    WHEN 16#10c# => mdio_wr_data <= data(15 downto 0);
                    WHEN 16#144# => address_mask(31 downto 0) <= data;
                    WHEN 16#148# => address_mask(47 downto 32) <= data(15 downto 0);
                    WHEN others  => null;
                end CASE;
            end if;

            if mdio_transaction_is_done(mdio_response) then
                mdio_rd_data <= get_mdio_read_data(mdio_response);
                mdio_busy    <= false;
            end if;

            if frame_sent     then frames_tx_ok <= frames_tx_ok + 1; end if;
            if tx_frame_error then out_errors   <= out_errors + 1;   end if;
            if received       then frames_rx_ok <= frames_rx_ok + 1; end if;
            if crc_error      then crc_errors   <= crc_errors + 1;   end if;
            if frame_error    then in_errors    <= in_errors + 1;    end if;

            if reset = '1' then
                command_config <= (others => '0');
                mac_address    <= (others => '0');
                address_mask   <= (others => '0');
                mdio_divider   <= (others => '0');
                mdio_reg_phy   <= (others => '0');
                mdio_wr_data   <= (others => '0');
                frames_tx_ok   <= (others => '0');
                frames_rx_ok   <= (others => '0');
                crc_errors     <= (others => '0');
                in_errors      <= (others => '0');
                out_errors     <= (others => '0');
            end if;
        end if;
    end process;

------------------------------------------------------------------------
    u_tx : entity work.ethernet_mac_tx
    port map(
        clock        => clock
        ,enable      => command_config(0) = '1'
        ,s_tvalid    => s_tvalid
        ,s_tready    => s_tready
        ,s_tdata     => s_tdata
        ,s_tlast     => s_tlast
        ,gmii_out    => tx_gmii
        ,frame_sent  => frame_sent
        ,frame_error => tx_frame_error
    );

    u_rgmii_tx : entity work.rgmii_tx
    port map(
        clock          => clock
        ,gmii_in       => tx_gmii
        ,delay_lo_half => false
        ,rgmii_out     => rgmii_tx_out
        ,tx_clock_out  => tx_clock_out
    );

------------------------------------------------------------------------
    config <= command_config(1) & command_config(4) & address_mask & mac_address;

    u_config_crossing : entity work.cdc_snapshot
    generic map(g_width => config_width)
    port map(
        source_clock       => clock
        ,source_data       => config
        ,destination_clock => rx_clock
        ,destination_data  => rx_config
    );

    u_rgmii_rx : entity work.rgmii_rx
    port map(
        clock           => rx_clock
        ,rgmii_in       => rgmii_rx_in
        ,gmii_out       => rx_gmii
        ,alignment      => open
        ,frame_is_ended => rx_frame_is_ended
    );

    process(rx_clock, rx_reset)
    begin
        if rx_reset = '1' then
            rx_reset_sync <= (others => '1');
        elsif rising_edge(rx_clock) then
            rx_reset_sync <= rx_reset_sync(0) & '0';
        end if;
    end process;

    u_rx : entity work.ethernet_mac_rx
    generic map(g_fifo_depth => g_rx_fifo_depth)
    port map(
        clock           => rx_clock
        ,clear          => rx_reset_sync(1) = '1'
        ,gmii_in        => rx_gmii
        ,frame_is_ended => rx_frame_is_ended
        ,enable         => rx_config(97) = '1'
        ,promiscuous    => rx_config(96) = '1'
        ,own_address    => rx_config(47 downto 0)
        ,address_mask   => rx_config(95 downto 48)
        ,m_tvalid       => m_tvalid
        ,m_tready       => m_tready
        ,m_tdata        => m_tdata
        ,m_tlast        => m_tlast
        ,frame_received => rx_received
        ,crc_error      => rx_crc_error
        ,frame_error    => rx_frame_error
    );

    -- the counters' pulses come at most one a frame, far enough apart for cdc_pulse
    u_received : entity work.cdc_pulse port map(rx_clock, rx_received, clock, received);
    u_crc_error : entity work.cdc_pulse port map(rx_clock, rx_crc_error, clock, crc_error);
    u_frame_error : entity work.cdc_pulse port map(rx_clock, rx_frame_error, clock, frame_error);

------------------------------------------------------------------------
    u_mdio_driver : entity work.mdio_driver
    generic map(g_clocks_per_half_mdc => g_clocks_per_half_mdc)
    port map(
        clock         => clock
        ,mdio_in      => mdio_request
        ,mdio_out     => mdio_response
        ,fpga_out     => mdio_pins
        ,fpga_mdio_in => mdio_in
    );

    mdc      <= mdio_pins.mdc;
    mdio_out <= mdio_pins.mdio_out;
    mdio_oe  <= mdio_pins.mdio_oe;

end architecture rtl;
