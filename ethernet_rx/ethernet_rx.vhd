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

    signal self : ethernet_receiver_record := init_ethernet_receiver;
    signal ethernet_ddio_out : ethernet_rx_ddio_data_output_group;

    signal ram_is_being_flushed : boolean := false;

begin

------------------------------------------------------------------------
    u_rxddio : entity work.ethernet_rx_ddio
    port map(clock, (ddio_input(9 downto 5), ddio_input(4 downto 0)), ethernet_ddio_out);
------------------------------------------------------------------------
    process(clock) is
    begin
        if rising_edge(clock) then
            create_ethernet_receiver(self, ethernet_ddio_out);
            -- count_only_frame_bytes(self);
            count_preamble_and_frame_bytes(self);

            init_ram_write(write_port);
            write_ethernet_frame_to_ram(self, write_port);

            if g_write_crc_to_receiver_ram then
                write_crc_to_receiver_ram(self, write_port);
            end if;

            rx_out.ram_is_flushed <= false;
            if empty_ram then
                ram_is_being_flushed <= true;
                self.receiver_ram_address <= 0;
            end if;

            if ram_is_being_flushed then
                if self.receiver_ram_address < 2**10-1 then
                    self.receiver_ram_address <= self.receiver_ram_address + 1;
                    write_data_to_ram(write_port, self.receiver_ram_address, x"00");
                else
                    rx_out.ram_is_flushed <= true;
                    ram_is_being_flushed <= false;
                    self.receiver_ram_address <= 0;
                end if;
            end if;
        end if;
    end process;

end rtl;
------------------------------------------------------------------------
