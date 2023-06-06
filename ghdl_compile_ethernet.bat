rem simulate ethernet.vhd
echo off

SET source=%1

ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_three_state_io_driver/mdio_three_state_io_driver_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_driver_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_driver_internal_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mmd_access_functions_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_driver.vhd

ghdl -a --ieee=synopsys --std=08 %source%/ethernet_rx_ddio/efinix_fpga_ddio_record.vhd
ghdl -a --ieee=synopsys --std=08 %source%/ethernet_rx_ddio/ethernet_rx_ddio_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/ethernet_rx_ddio/efinix_rx_ddio.vhd
ghdl -a --ieee=synopsys --std=08 %source%/ethernet_clocks_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/ethernet_common/PCK_CRC_32_D8.vhd

ghdl -a --ieee=synopsys --std=08 %source%/ethernet_common/dual_port_ethernet_ram/ethernet_frame_ram_write_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/ethernet_frame_receiver/ethernet_frame_receiver_pkg.vhd

