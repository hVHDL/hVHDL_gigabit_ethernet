library ieee;
    use ieee.std_logic_1164.all;

-- Two frame streams onto one (ethernet_mac's transmit stream): a whole frame from a or b at a
-- time, a first when both have one. A frame is passed through as it comes, so a stream that
-- is without gaps stays so.
entity frame_mux is
    port(
        clock    : in std_logic;

        a_tvalid : in std_logic;
        a_tready : out std_logic;
        a_tdata  : in std_logic_vector(7 downto 0);
        a_tlast  : in std_logic;

        b_tvalid : in std_logic;
        b_tready : out std_logic;
        b_tdata  : in std_logic_vector(7 downto 0);
        b_tlast  : in std_logic;

        m_tvalid : out std_logic;
        m_tready : in std_logic;
        m_tdata  : out std_logic_vector(7 downto 0);
        m_tlast  : out std_logic
    );
end entity frame_mux;

architecture rtl of frame_mux is
    type sources is (none, a, b);
    signal selected : sources := none;
begin

    m_tvalid <= a_tvalid when selected = a else b_tvalid when selected = b else '0';
    m_tdata  <= b_tdata when selected = b else a_tdata;
    m_tlast  <= a_tlast when selected = a else b_tlast when selected = b else '0';
    a_tready <= m_tready when selected = a else '0';
    b_tready <= m_tready when selected = b else '0';

    process(clock)
    begin
        if rising_edge(clock) then
            CASE selected is
                WHEN none =>
                    if a_tvalid = '1' then
                        selected <= a;
                    elsif b_tvalid = '1' then
                        selected <= b;
                    end if;
                WHEN a =>
                    if a_tvalid = '1' and m_tready = '1' and a_tlast = '1' then
                        selected <= none;
                    end if;
                WHEN b =>
                    if b_tvalid = '1' and m_tready = '1' and b_tlast = '1' then
                        selected <= none;
                    end if;
            end CASE;
        end if;
    end process;

end architecture rtl;
