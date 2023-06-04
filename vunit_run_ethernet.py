#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv()

eth = VU.add_library("ethernet")
eth.add_source_files(ROOT / "mdio_driver/mdio_driver.vhd")
eth.add_source_files(ROOT / "mdio_driver/mdio_driver_internal_pkg.vhd")
eth.add_source_files(ROOT / "mdio_driver/mdio_driver_pkg.vhd")
eth.add_source_files(ROOT / "mdio_driver/mdio_three_state_io_driver/mdio_three_state_io_driver_pkg.vhd")

eth.add_source_files(ROOT / "testbenches/mdio_driver_simulation/tb_mdio_driver.vhd")
eth.add_source_files(ROOT / "testbenches/mdio_driver_simulation/mdio_tb.vhd")

VU.main()
