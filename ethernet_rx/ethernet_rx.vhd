library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ethernet_rx_pkg.all;
    use work.ethernet_frame_ram_read_pkg.all;
    use work.ethernet_frame_ram_write_pkg.all;
    use work.ethernet_frame_receiver_pkg.all;
    use work.ethernet_rx_ddio_pkg.all;

entity ethernet_rx is
    generic(g_count_preamble_and_frame_bytes : boolean := true;
            g_write_crc_to_receiver_ram      : boolean := true);
    port (
        clock          : in std_logic;
        ddio_input     : in std_logic_vector(9 downto 0);
        empty_ram      : in boolean;
        rx_out         : out ethernet_rx_output_record;
        write_port     : out ram_write_control_record
    );
end entity ethernet_rx;


architecture rtl of ethernet_rx is

    signal ethernet_receiver : ethernet_receiver_record := init_ethernet_receiver;
    signal ethernet_ddio_out : ethernet_rx_ddio_data_output_group;

    signal ram_is_being_flushed : boolean := false;

    signal ctl_buffer : std_logic_vector(1 downto 0) := "00";

begin

------------------------------------------------------------------------
    u_rxddio : entity work.ethernet_rx_ddio
    port map(clock, (ddio_input(9 downto 5), ddio_input(4 downto 0)), ethernet_ddio_out);
------------------------------------------------------------------------
    process(clock) is
        variable ctl : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clock) then
            rx_out.frame_is_received <= receiver_is_ready(ethernet_receiver);
            create_ethernet_receiver(ethernet_receiver, ethernet_ddio_out);
            -- count_only_frame_bytes(ethernet_receiver);
            count_preamble_and_frame_bytes(ethernet_receiver);

            init_ram_write(write_port);
            write_ethernet_frame_to_ram(ethernet_receiver, write_port);

            if g_write_crc_to_receiver_ram then
                write_crc_to_receiver_ram(ethernet_receiver, write_port);
            end if;

            rx_out.ram_is_flushed <= false;
            if empty_ram then
                ram_is_being_flushed <= true;
                ethernet_receiver.receiver_ram_address <= 0;
            end if;

            if ram_is_being_flushed then
                if ethernet_receiver.receiver_ram_address < 2**10-1 then
                    ethernet_receiver.receiver_ram_address <= ethernet_receiver.receiver_ram_address + 1;
                    write_data_to_ram(write_port, ethernet_receiver.receiver_ram_address, x"00");
                else
                    rx_out.ram_is_flushed <= true;
                    ram_is_being_flushed <= false;
                    ethernet_receiver.receiver_ram_address <= 0;
                end if;
            end if;
        end if;
    end process;

end rtl;
------------------------------------------------------------------------
