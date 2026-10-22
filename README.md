# gigabit_ethernet
synthesizable minimal gigabit ethernet with RGMII interface

The ethernet communication is explored in following blog posts

overview and MDIO :
https://hardwaredescriptions.com/gigabit-ethernet-vol1-mdio-and-communications-wonderland/

RGMII : 
https://hardwaredescriptions.com/ethernet-vol2-a-look-to-the-rgmii-connection/

ethernet, ip and udp frame header parsing : 
https://hardwaredescriptions.com/gigabit-ethernet-vol-3-processing-protocols-from-reasonably-accessible-memory/

rgmii transmitter :
https://hardwaredescriptions.com/ethernet-vol-4-txing/

## ethernet_mac

ethernet_mac/ is a gigabit Ethernet MAC on RGMII with 8 bit AXI streams and an APB3 register
slave, at the register offsets of Efinix's Triple Speed Ethernet MAC so that the Zephyr
drivers for it work unchanged. Transmit: ethernet_mac_tx adds the preamble, padding and FCS.
Receive: ethernet_mac_rx is a store and forward FIFO that drops frames with a bad CRC, a bad
length or another address. MDIO goes through mdio_driver. The device specific DDIO
primitives stay outside: rgmii_rx and rgmii_tx take and give the DDIO halves.

It is self contained and does not use the older sources of this repository; some file names
(ethernet_pkg, mdio_driver) are the same, so compile it into a library of its own. The
receive FIFO uses simple_dual_port_ram from hVHDL_memory_library (a submodule here).

Tests, with VUnit and nvc:

    git submodule update --init
    python3 vunit_run_ethernet_mac.py -p 8
