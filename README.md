# FPGA UDP Traffic Generator (Nexys A7)

## Overview

This project implements a hardware UDP traffic generator on a Xilinx Nexys A7 (Artix-7) FPGA. UDP packets are generated entirely in hardware and transmitted over a 10/100 Mbps Ethernet connection, where they can be captured and analyzed on a host computer using Wireshark.

Instead of building an entire networking stack from scratch, I integrated two existing open-source projects:

- **Alex Forencich's `verilog-ethernet`** for the IPv4 and UDP protocol layers.
- **Nexys 4 DDR Ethernet MAC** for the Ethernet MAC and RMII interface used by the Nexys A7's onboard Ethernet PHY.

Both projects are included under `udp_stack_infrastructure/`.

---

## What I Worked On

The goal of this project was to integrate the networking stack with the Ethernet MAC and develop the application-layer hardware responsible for generating UDP traffic.

### `top.v`

Modified the top-level design to:

- Instantiate the Ethernet MAC and UDP/IP wrapper
- Connect the custom traffic generator to the UDP stack
- Map FPGA switches and pushbuttons to the application
- Route status information to the onboard LEDs

### `udp_complete_wrapper.v`

Modified the wrapper to expose a simple interface between the application logic and the UDP/IP stack, allowing the traffic generator to transmit UDP packets.

### `udp_traffic_generator.sv`

Implemented a custom UDP traffic generator that handles:

- Packet generation using a finite state machine
- Configurable packet count
- Payload generation
- Packet sequencing
- AXI-Stream transmit handshaking
- Sending packet data into the UDP stack

### `udp_traffic_generator_tb.sv`

Created a SystemVerilog testbench to verify:

- FSM operation
- Packet counter behavior
- Payload generation
- Packet sequencing
- AXI-Stream handshake logic

---

## Features

- Hardware UDP packet generation
- Configurable packet count using FPGA switches
- Pushbutton-controlled packet transmission
- Custom payload generation
- Sequence number embedded in every packet
- UDP transmission over Ethernet
- Successfully synthesized and tested on a Nexys A7 FPGA
- Packet transmission verified using Wireshark

---

## Technologies

- SystemVerilog
- Xilinx Vivado
- Xilinx Artix-7 FPGA
- Nexys A7 Development Board
- RMII Ethernet
- Ethernet MAC
- IPv4
- UDP
- AXI-Stream
- Wireshark

---

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
