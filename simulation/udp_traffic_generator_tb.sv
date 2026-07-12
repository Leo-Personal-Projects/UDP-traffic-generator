// Testbench
`timescale 1ns / 1ps
`default_nettype none

module udp_traffic_generator_tb;

    logic clock;
    logic reset_L;

    logic tx_udp_hdr_ready;
    logic tx_udp_payload_axis_tready;

    logic start_send;
    logic [3:0] packet_count;
    logic [31:0] local_ip;

    logic tx_udp_hdr_valid;
    logic [5:0]  tx_udp_ip_dscp;
    logic [1:0]  tx_udp_ip_ecn;
    logic [7:0]  tx_udp_ip_ttl;
    logic [31:0] tx_udp_ip_source_ip;
    logic [31:0] tx_udp_ip_dest_ip;
    logic [15:0] tx_udp_source_port;
    logic [15:0] tx_udp_dest_port;
    logic [15:0] tx_udp_length;
    logic [15:0] tx_udp_checksum;

    logic [7:0] tx_udp_payload_axis_tdata;
    logic       tx_udp_payload_axis_tvalid;
    logic       tx_udp_payload_axis_tlast;
    logic       tx_udp_payload_axis_tuser;

    logic [7:0] led_out;

    udp_traffic_generator dut (
        .tx_udp_hdr_ready(tx_udp_hdr_ready),
        .tx_udp_payload_axis_tready(tx_udp_payload_axis_tready),
        .start_send(start_send),
        .packet_count(packet_count),
        .local_ip(local_ip),
        .clock(clock),
        .reset_L(reset_L),

        .tx_udp_hdr_valid(tx_udp_hdr_valid),
        .tx_udp_ip_dscp(tx_udp_ip_dscp),
        .tx_udp_ip_ecn(tx_udp_ip_ecn),
        .tx_udp_ip_ttl(tx_udp_ip_ttl),
        .tx_udp_ip_source_ip(tx_udp_ip_source_ip),
        .tx_udp_ip_dest_ip(tx_udp_ip_dest_ip),
        .tx_udp_source_port(tx_udp_source_port),
        .tx_udp_dest_port(tx_udp_dest_port),
        .tx_udp_length(tx_udp_length),
        .tx_udp_checksum(tx_udp_checksum),

        .tx_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
        .tx_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
        .tx_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
        .tx_udp_payload_axis_tuser(tx_udp_payload_axis_tuser),

        .led_out(led_out)
    );

    // 50 MHz clock
    initial clock = 0;
    always #10 clock = ~clock;

    initial begin

        reset_L = 0;

        start_send = 0;
        packet_count = 4'd3;
        local_ip = 32'h0A000002;

        tx_udp_hdr_ready = 1;
        tx_udp_payload_axis_tready = 1;

        // Reset
        repeat (5) @(posedge clock);
        reset_L = 1;

        // Wait a little
        repeat (3) @(posedge clock);

        // Hold start high for two cycles
        start_send = 1;
        repeat (2) @(posedge clock);
        start_send = 0;

        // Run
        repeat (100) @(posedge clock);

        $finish;
    end

    initial begin
        $display("time state next pkt payload hdr pay last");

        forever begin
            @(posedge clock);

            $display("%0t %0d %0d %0d %0d %0b %0b %0b",
                $time,
                dut.state,
                dut.next_state,
                dut.curr_packet_count,
                dut.payload_index,
                tx_udp_hdr_valid,
                tx_udp_payload_axis_tvalid,
                tx_udp_payload_axis_tlast
            );
        end
    end

endmodule : udp_traffic_generator_tb

`default_nettype wire