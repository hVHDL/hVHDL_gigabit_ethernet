rem simulate ethernet_frame_receiver.vhd
echo off

echo %project_root%
FOR /F "tokens=* USEBACKQ" %%F IN (`git rev-parse --show-toplevel`) DO (
SET project_root=%%F
)
SET source=%project_root%/source
ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet/ethernet_clocks_pkg.vhd 
ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet_common/dual_port_ethernet_ram/ethernet_frame_ram_write_pkg.vhd
ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet/ethernet_frame_receiver/ethernet_rx_ddio/ethernet_rx_ddio_pkg.vhd

ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet/ethernet_common/PCK_CRC_32_D8.vhd 
ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet/ethernet_frame_receiver/ethernet_rx_ddio/ethernet_rx_ddio.vhd
ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet/ethernet_frame_receiver/ethernet_rx_ddio/arch_ethernet_rx_ddio_simulation.vhd
ghdl -a --ieee=synopsys ..\ethernet_frame_receiver_pkg.vhd
ghdl -a --ieee=synopsys ..\ethernet_frame_receiver_internal_pkg.vhd
ghdl -a --ieee=synopsys ..\ethernet_frame_receiver.vhd
ghdl -a --ieee=synopsys tb_ethernet_frame_receiver.vhd
ghdl -e --ieee=synopsys tb_ethernet_frame_receiver
ghdl -r --ieee=synopsys tb_ethernet_frame_receiver --vcd=tb_ethernet_frame_receiver.vcd


IF %1 EQU 1 start "" gtkwave tb_ethernet_frame_receiver.vcd
