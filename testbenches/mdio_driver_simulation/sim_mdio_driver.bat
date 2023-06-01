rem simulate mdio_driver.vhd
echo off

echo %project_root%
FOR /F "tokens=* USEBACKQ" %%F IN (`git rev-parse --show-toplevel`) DO (
SET project_root=%%F
)
SET source=%project_root%/source

ghdl -a --ieee=synopsys ..\mdio_three_state_io_driver\mdio_three_state_io_driver_pkg.vhd
ghdl -a --ieee=synopsys ..\mdio_three_state_io_driver\mdio_three_state_io_driver.vhd
ghdl -a --ieee=synopsys ..\mdio_driver_pkg.vhd
ghdl -a --ieee=synopsys ..\mdio_driver_internal_pkg.vhd
ghdl -a --ieee=synopsys ..\mmd_access_functions_pkg.vhd
ghdl -a --ieee=synopsys ..\mdio_driver.vhd
ghdl -a --ieee=synopsys tb_mdio_driver.vhd
ghdl -e --ieee=synopsys tb_mdio_driver
ghdl -r --ieee=synopsys tb_mdio_driver --vcd=tb_mdio_driver.vcd


IF %1 EQU 1 start "" gtkwave tb_mdio_driver.vcd
