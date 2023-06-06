#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv()

eth = VU.add_library("eth")
eth.add_source_files(ROOT / "mdio_driver/mdio_driver.vhd")
eth.add_source_files(ROOT / "mdio_driver/mdio_driver_internal_pkg.vhd")
eth.add_source_files(ROOT / "mdio_driver/mdio_driver_pkg.vhd")
eth.add_source_files(ROOT / "mdio_driver/mdio_three_state_io_driver/mdio_three_state_io_driver_pkg.vhd")


eth.add_source_files(ROOT / "ethernet_rx_ddio/efinix_fpga_ddio_record.vhd")
eth.add_source_files(ROOT / "ethernet_rx_ddio/ethernet_rx_ddio_pkg.vhd")
eth.add_source_files(ROOT / "ethernet_clocks_pkg.vhd")
eth.add_source_files(ROOT / "ethernet_common/PCK_CRC_32_D8.vhd")

eth.add_source_files(ROOT / "ethernet_common/dual_port_ethernet_ram/ethernet_frame_ram_write_pkg.vhd")
eth.add_source_files(ROOT / "ethernet_frame_receiver/ethernet_frame_receiver_pkg.vhd")
eth.add_source_files(ROOT / "ethernet_common/dual_port_ethernet_ram/ethernet_frame_ram_read_pkg.vhd")
eth.add_source_files(ROOT / "ethernet_common/dual_port_ethernet_ram/ethernet_frame_ram_write_pkg.vhd")

eth.add_source_files(ROOT / "testbenches/mdio_driver_simulation/tb_mdio_driver.vhd")
eth.add_source_files(ROOT / "testbenches/mdio_driver_simulation/mdio_tb.vhd")

eth.add_source_files(ROOT / "testbenches/ethernet_receiver/receiver_tb.vhd")
eth.add_source_files(ROOT / "testbenches/receiver_ram/receiver_ram_tb.vhd")

VU.main()
