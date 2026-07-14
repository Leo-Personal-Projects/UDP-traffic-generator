/* 
 * File: udp_traffic_generator.sv
 * 
 * This file generates and controls the transmission of UDP packets 
 * to be sent via an FPGA using counters and an FSM.
 * 
 * Author: Leo Serodio
 */


`timescale 1ns / 1ps
`default_nettype none

module udp_traffic_generator (
    input  logic        tx_udp_hdr_ready,
    input  logic        tx_udp_payload_axis_tready,

    input  logic        start_send,
    input  logic [3:0]  packet_count,
    input  logic [31:0] local_ip,

    input  logic        clock,
    input  logic        reset_L,

    output logic        tx_udp_hdr_valid,
    output logic [5:0]  tx_udp_ip_dscp,
    output logic [1:0]  tx_udp_ip_ecn,
    output logic [7:0]  tx_udp_ip_ttl,
    output logic [31:0] tx_udp_ip_source_ip,
    output logic [31:0] tx_udp_ip_dest_ip,
    output logic [15:0] tx_udp_source_port,
    output logic [15:0] tx_udp_dest_port,
    output logic [15:0] tx_udp_length,
    output logic [15:0] tx_udp_checksum,

    output logic [7:0]  tx_udp_payload_axis_tdata,
    output logic        tx_udp_payload_axis_tvalid,
    output logic        tx_udp_payload_axis_tlast,
    output logic        tx_udp_payload_axis_tuser,

    output logic [7:0]  led_out
);

    // Destination PC info
    localparam logic [31:0] PC_IP        = {8'd10, 8'd0, 8'd0, 8'd1};
    localparam logic [15:0] FPGA_PORT    = 16'd1234;
    localparam logic [15:0] PC_PORT      = 16'd5000;

    // Payload is 4 bytes: "P", "K", "T", sequence_number
    // The reasoning behidn the seq number is so that in wireshark
    // we can see which packets were lost or if they were sent out of order
    
    // Make compile-time constant using localparam for better style
    localparam logic [15:0] PAYLOAD_LEN = 16'd4;
    localparam logic [15:0] UDP_LEN     = 16'd8 + PAYLOAD_LEN;

    // Constant UDP/IP header fields
    always_comb begin
        tx_udp_ip_dscp      = 6'd0;
        tx_udp_ip_ecn       = 2'd0;
        tx_udp_ip_ttl       = 8'd64;
        tx_udp_ip_source_ip = local_ip;
        tx_udp_ip_dest_ip   = PC_IP;
        tx_udp_source_port  = FPGA_PORT;
        tx_udp_dest_port    = PC_PORT;
        tx_udp_length       = UDP_LEN;
        tx_udp_checksum     = 16'd0;
        tx_udp_payload_axis_tuser = 1'b0;
    end

    // Counter stores packets left to send
    logic       ctr_en;
    logic       ctr_clear;
    logic       ctr_load;
    logic [3:0] curr_packet_count;

    // Counter used to track packet count
    Counter #(4) ctr (
        .D(packet_count),
        .Q(curr_packet_count),
        .en(ctr_en),
        .clear(ctr_clear),
        .load(ctr_load),
        .up(1'b0), // count down
        .clock(clock)
    );

    // Tracks which payload byte we are sending
    logic       payload_ctr_en;
    logic       payload_ctr_clear;
    logic [1:0] payload_index;

    // Counter used to track the payload byte index within a packet
    Counter #(2) payload_ctr (
        .D     (2'd0),
        .Q     (payload_index),
        .en    (payload_ctr_en),
        .clear (payload_ctr_clear || ~reset_L),
        .load  (1'b0),
        .up    (1'b1),  // count upward from 0 to 3
        .clock (clock)
    );

    // Sequence number placed in 4th payload byte
    logic [7:0] seq_num;

    enum logic [2:0] {
        IDLE,
        LOAD,
        SEND_HEADER,
        SEND_PAYLOAD,
        DECREMENT,
        DONE
    } state, next_state;

    always_ff @(posedge clock) begin
        if (~reset_L)
            seq_num <= 8'd0;
        else if (state == DECREMENT && curr_packet_count != 4'd0)
            seq_num <= seq_num + 8'd1;
    end
    
    always_ff @(posedge clock) begin
        if (~reset_L)
            state <= IDLE;
        else
            state <= next_state;
    end


    // Next-state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start_send)
                    next_state = LOAD;
            end

            LOAD: begin
                if (packet_count == 4'd0)
                    next_state = DONE;
                else
                    next_state = SEND_HEADER;
            end

            SEND_HEADER: begin
                if (tx_udp_hdr_ready)
                    next_state = SEND_PAYLOAD;
            end
            // Leave SEND_PAYLOAD only after the final payload byte has been
            // accepted by the UDP stack through the AXI-Stream handshake (via tready & tvalid)
            // tvalid is always 1 => tx_udp_payload_axis_tvalid = 1'b1; so just tready matters here
            SEND_PAYLOAD: begin
                if (tx_udp_payload_axis_tready && payload_index == 2'd3)
                    next_state = DECREMENT;
            end

            DECREMENT: begin
                if (curr_packet_count == 4'd1)
                    next_state = DONE;
                else
                    next_state = SEND_HEADER;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always_comb begin
        ctr_en            = 1'b0;
        ctr_clear         = 1'b0;
        ctr_load          = 1'b0;
        payload_ctr_en    = 1'b0;
        payload_ctr_clear = 1'b0;

        tx_udp_hdr_valid = 1'b0;

        tx_udp_payload_axis_tvalid = 1'b0;
        tx_udp_payload_axis_tlast  = 1'b0;
        tx_udp_payload_axis_tdata  = 8'h00;


        case (state)
            IDLE: begin
                ctr_clear = 1'b1;
                payload_ctr_clear = 1'b1;
            end

            LOAD: begin
                ctr_load = 1'b1;
            end

            SEND_HEADER: begin
                tx_udp_hdr_valid = 1'b1;
                payload_ctr_clear = 1'b1;
            end

            SEND_PAYLOAD: begin
                tx_udp_payload_axis_tvalid = 1'b1;
                tx_udp_payload_axis_tlast  = (payload_index == 2'd3); // UDP stack needs to know when last byte occurs
                // Depending on current payload byte index, we sent corresponding data (Artifically build packet)
                case (payload_index)
                    2'd0: tx_udp_payload_axis_tdata = 8'h50;    // P
                    2'd1: tx_udp_payload_axis_tdata = 8'h4B;    // K
                    2'd2: tx_udp_payload_axis_tdata = 8'h54;    // T
                    2'd3: tx_udp_payload_axis_tdata = seq_num;  // sequence number
                    default: tx_udp_payload_axis_tdata = 8'h00;
                endcase

                if (tx_udp_payload_axis_tready)
                    payload_ctr_en = 1'b1;
            end

            DECREMENT: begin
                ctr_en = 1'b1;
                
            end

            DONE: begin
                payload_ctr_clear = 1'b1;
            end
        endcase
    end

    // LEDs show FSM state and packets left
    assign led_out = {1'b0, state, curr_packet_count};

endmodule : udp_traffic_generator


// Simple Counter module (18-240 style)
module Counter
    #(parameter WIDTH = 4)
     (input  logic [WIDTH-1:0] D,
      output logic [WIDTH-1:0] Q,
      input  logic en,
      input  logic clear,
      input  logic load,
      input  logic up,
      input  logic clock);

    always_ff @(posedge clock) begin
        if (clear)
            Q <= '0;
        else if (load)
            Q <= D;
        else if (en && up)
            Q <= Q + 1'b1;
        else if (en)
            Q <= Q - 1'b1;
    end

endmodule : Counter

`default_nettype wire // use Alex Forencich strat (normal verilog behavior for files compiled after)

