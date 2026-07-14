# FPGA UDP Traffic Generator (Nexys A7)

This project implements a UDP traffic generator on a Xilinx Nexys A7 (Artix-7) FPGA. UDP packets are generated completely in hardware and transmitted over the board's 10/100 Mbps Ethernet interface, where they can be captured and inspected in Wireshark.

Rather than writing an entire networking stack from scratch, I integrated two open-source projects into the design:

- Alex Forencich's `verilog-ethernet` for the IPv4 and UDP protocol stack
- Nexys 4 DDR Ethernet MAC for the Ethernet MAC and RMII interface

Both are included in the `udp_stack_infrastructure/` directory.

## My Contributions

Most of my work focused on integrating the networking components and building the application logic that generates UDP traffic.

### `top.v`

- Connected the Ethernet MAC and UDP/IP stack
- Integrated the custom UDP traffic generator
- Connected FPGA switches, buttons, and LEDs for user control and status

### `udp_complete_wrapper.v`

Modified the wrapper so the application logic could easily send UDP packets through the networking stack.

### `udp_traffic_generator.sv`

Designed a finite state machine that:

- Generates UDP payloads
- Sends a user-selected number of packets
- Handles AXI-Stream transmit handshaking
- Adds a sequence number to each packet before transmission

### `udp_traffic_generator_tb.sv`

Built a SystemVerilog testbench to verify the state machine, packet counter, payload generation, and AXI-Stream interface before running on hardware.

## Results

- Successfully synthesized on a Nexys A7 FPGA
- UDP packets transmitted over Ethernet
- Packet captures verified in Wireshark
- Packet count controlled with onboard switches
- Transmission started using the onboard pushbutton

## Tools Used

- SystemVerilog
- Xilinx Vivado
- Nexys A7 (Artix-7)
- Ethernet / UDP
- AXI-Stream
- Wireshark

## Repository Structure

```text
rtl/
    top.v
    debounce.v
    udp_complete_wrapper.v
    udp_traffic_generator.sv

simulation/
    udp_traffic_generator_tb.sv

udp_stack_infrastructure/
    verilog-ethernet/
    Nexys-4-DDR-Ethernet-Mac/

constraints/
    *.xdc
```