library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_pkg.all;

-- The transmit side of ethernet_mac: frames from an 8 bit AXI stream, from the destination
-- address to the end of the payload, onto GMII with the preamble, the SFD, zero padding to 60
-- bytes, the FCS and the interframe gap.
--
-- The stream must give a frame without gaps once its first byte is taken (a store and forward
-- stage in front, such as tx_checksum_inserter, does): tready is held low through the
-- preamble and then high until tlast. A frame whose bytes stop coming before tlast is cut
-- short with TX_ER on the line and the rest of it is taken and thrown away. With
-- enable low, frames are taken and thrown away whole.
--
-- counters, each a clock pulse: frame_sent, frame_error (a frame cut short).
entity ethernet_mac_tx is
    port(
        clock       : in std_logic;
        enable      : in boolean;

        s_tvalid    : in std_logic;
        s_tready    : out std_logic;
        s_tdata     : in std_logic_vector(7 downto 0);
        s_tlast     : in std_logic;

        gmii_out    : out gmii_record;

        frame_sent  : out boolean;
        frame_error : out boolean
    );
end entity ethernet_mac_tx;

architecture rtl of ethernet_mac_tx is

    constant minimum_length : natural := 60;
    constant gap_length     : natural := 12;

    type states is (idle, preamble, data, padding, fcs, gap, discard);
    signal state  : states := idle;
    signal index  : natural range 0 to 2047 := 0;
    signal length : natural range 0 to 2047 := 0;
    signal crc    : std_logic_vector(31 downto 0) := crc32_init;
    signal cut    : boolean := false;

begin

    s_tready <= '1' when state = data or state = discard else '0';

    process(clock)
        procedure output(value : byte) is
        begin
            gmii_out <= (data => value, is_valid => true, is_error => false);
        end procedure;

        procedure output_with_crc(value : byte) is
        begin
            output(value);
            crc <= next_crc32(crc, value);
        end procedure;

        procedure after_payload(bytes : natural) is
        begin
            index <= 0;
            if bytes < minimum_length then
                length <= bytes;
                state  <= padding;
            else
                state  <= fcs;
            end if;
        end procedure;
    begin
        if rising_edge(clock) then
            gmii_out    <= gmii_idle;
            frame_sent  <= false;
            frame_error <= false;

            CASE state is
                WHEN idle =>
                    index <= 0;
                    cut   <= false;
                    if s_tvalid = '1' then
                        if enable then
                            state <= preamble;
                        else
                            state <= discard;
                        end if;
                    end if;

                WHEN preamble =>
                    if index < 7 then
                        output(preamble_byte);
                        index <= index + 1;
                    else
                        output(start_of_frame_byte);
                        crc   <= crc32_init;
                        index <= 0;
                        state <= data;
                    end if;

                WHEN data =>
                    if s_tvalid = '1' then
                        output_with_crc(s_tdata);
                        if index < 2047 then
                            index <= index + 1;
                        end if;
                        if s_tlast = '1' then
                            after_payload(index + 1);
                        end if;
                    else
                        -- the stream ran dry: the frame is spoilt on the line
                        gmii_out    <= (data => x"00", is_valid => true, is_error => true);
                        frame_error <= true;
                        cut   <= true;
                        state <= discard;
                    end if;

                WHEN padding =>
                    output_with_crc(x"00");
                    if length < minimum_length-1 then
                        length <= length + 1;
                    else
                        state <= fcs;
                    end if;

                WHEN fcs =>
                    output(fcs_byte(crc, index));
                    if index < 3 then
                        index <= index + 1;
                    else
                        index      <= 0;
                        frame_sent <= true;
                        state      <= gap;
                    end if;

                WHEN gap =>
                    if index < gap_length-1 then
                        index <= index + 1;
                    else
                        state <= idle;
                    end if;

                WHEN discard =>
                    if s_tvalid = '1' and s_tlast = '1' then
                        index <= 0;
                        if cut then
                            state <= gap;
                        else
                            state <= idle;
                        end if;
                    end if;
            end CASE;
        end if;
    end process;

end architecture rtl;
