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

## network_responder

ethernet_mac/network_responder.vhd gives an FPGA an address on the network, between
ethernet_mac's receive and transmit streams: it answers ARP and ICMP echo (ping) for its IP,
echoes UDP datagrams sent to a port, and sends frames with a test EtherType (0x88B5) back.
IPv4 is answered without options or fragments and with a good header checksum. A reply is its
request with a few fields changed (addresses, opcode/type, ports), sent from a frame buffer
behind a reply header, so the IP header and UDP checksums stay right as they are and only the
ICMP checksum is updated (RFC 1624). The buffer is a simple dual port RAM across the receive
and transmit clocks; one frame at a time, the others wait in ethernet_mac's receive FIFO.
Own address, IP and UDP port are inputs (quasi static), the replies are counted with pulses.

## sharing a port with another MAC

With g_shared_port, ethernet_mac shares its PHY with a second MAC at the GMII level, such as
a processor's MAC next to it in the same chip, each with its own address: share_rx_out gives
the other MAC every received frame as it was on the line (preamble, SFD and FCS too, from
rgmii_rx's line_out), and ethernet_mac/gmii_share.vhd puts the frames of its GMII transmit,
share_tx_in, onto the line between ethernet_mac's own. GMII has no back-pressure, so those
frames go through a store and forward FIFO and have priority: ethernet_mac_tx is held off
(its hold input) while the FIFO has a frame, and as the other MAC sends no faster than the
line, the FIFO never holds more than what came during one of ethernet_mac's frames. Frames
with TX_ER or longer than the FIFO are dropped whole. Both are counted (registers 0x180,
0x184).

Tests, with VUnit and nvc:

    git submodule update --init
    python3 vunit_run_ethernet_mac.py -p 8
