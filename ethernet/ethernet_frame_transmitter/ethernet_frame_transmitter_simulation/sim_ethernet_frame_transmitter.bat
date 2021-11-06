rem simulate ethernet_frame_transmitter.vhd
rem
echo off
FOR /F "tokens=* USEBACKQ" %%F IN (`git rev-parse --show-toplevel`) DO (
SET project_root=%%F
)
SET source=%project_root%/source


ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet/ethernet_clocks_pkg.vhd 
    ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet_common/PCK_CRC_32_D8.vhd 


rem ghdl -a --ieee=synopsys %ethernet_mac_source%\ethernet_frame_transmitter\ethernet_frame_transmitter_pkg.vhd
rem ghdl -a --ieee=synopsys %ethernet_mac_source%\ethernet_frame_transmitter\ethernet_frame_transmitter_internal_pkg.vhd
            ghdl -a --ieee=synopsys %source%/system_control/system_components/ethernet_communication/ethernet/ethernet_frame_transmitter/ethernet_frame_transmit_controller_pkg.vhd

ghdl -a --ieee=synopsys tb_ethernet_frame_transmitter.vhd
ghdl -e --ieee=synopsys tb_ethernet_frame_transmitter
ghdl -r --ieee=synopsys tb_ethernet_frame_transmitter --vcd=tb_ethernet_frame_transmitter.vcd


IF %1 EQU 1 start "" gtkwave tb_ethernet_frame_transmitter.vcd
