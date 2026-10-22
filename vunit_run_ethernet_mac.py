#!/usr/bin/env python3
# VUnit testbenches of ethernet_mac/, from the root of this repository:
#   git submodule update --init
#   python3 vunit_run_ethernet_mac.py [test pattern] [-p N]
# Uses nvc unless VUNIT_SIMULATOR is set.
import os
from pathlib import Path
from vunit import VUnit

os.environ.setdefault("VUNIT_SIMULATOR", "nvc")
root = Path(__file__).resolve().parent

vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()
lib = vu.add_library("mac")

# the receive FIFO's RAM
memory = root / "submodules" / "hVHDL_memory_library" / "vhdl2008"
lib.add_source_files(memory / "dp_ram_w_configurable_records.vhd")
lib.add_source_files(memory / "sdp_ram_w_configurable_records.vhd")

lib.add_source_files(root / "ethernet_mac" / "*.vhd")
lib.add_source_files(root / "ethernet_mac" / "sim" / "*.vhd")

mac_tb = lib.test_bench("ethernet_mac_tb")
mac_tb.add_config(name="rx_lo_aligned", generics=dict(rx_lo_lags=False))
mac_tb.add_config(name="rx_lo_lags", generics=dict(rx_lo_lags=True))

vu.main()
