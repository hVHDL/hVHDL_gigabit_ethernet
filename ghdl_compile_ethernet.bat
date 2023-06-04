rem simulate ethernet.vhd
echo off

SET source=%1

ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_three_state_io_driver/mdio_three_state_io_driver_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_driver_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_driver_internal_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mmd_access_functions_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %source%/mdio_driver/mdio_driver.vhd
