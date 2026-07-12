`timescale 1 ns / 1 ps

module top
(
    input             clk_100,
    input             cpu_rst_n,

    output            eth_mdc,
    inout             eth_mdio,
    output            eth_rstn,
    inout             eth_crsdv,
    inout             eth_rxerr,
    inout  [1:0]      eth_rxd,
    output            eth_txen,
    output [1:0]      eth_txd,
    output            eth_clkin,
    inout             eth_intn,
    input      [15:0] sw,
    output reg [15:0] led,
    input             btnu
);

    wire clk_mac;
    wire clk_phy;
    wire clk_fb;
    wire pll_locked;

    PLLE2_BASE #(
        .CLKFBOUT_MULT (10),
        .CLKOUT0_DIVIDE(20),
        .CLKOUT1_DIVIDE(20),
        .CLKOUT1_PHASE (45.0),
        .CLKIN1_PERIOD (10.0)
    )
    clk_gen (
        .CLKOUT0 (clk_mac),
        .CLKOUT1 (clk_phy),
        .CLKFBOUT(clk_fb),
        .LOCKED  (pll_locked),
        .CLKIN1  (clk_100),
        .RST     (1'b0),
        .CLKFBIN (clk_fb)
    );

    reg        rst_n         = 1'b0;
    reg [15:0] rst_n_counter = 16'd0;

    always @(posedge clk_mac) begin
        rst_n         <= (rst_n || &rst_n_counter) && pll_locked && cpu_rst_n;
        rst_n_counter <= rst_n ? 16'd0 : rst_n_counter + 16'd1;
    end

    wire btnu_d;

    debounce #(1) btnu_debounce (
        .clk(clk_mac),
        .in (btnu),
        .out(btnu_d)
    );

    (* mark_debug = "true" *)
    wire [7:0] rx_axis_mac_tdata;
    (* mark_debug = "true" *)
    wire       rx_axis_mac_tvalid;
    (* mark_debug = "true" *)
    wire       rx_axis_mac_tlast;
    (* mark_debug = "true" *)
    wire       rx_axis_mac_tuser;

    (* mark_debug = "true" *)
    wire [7:0] tx_axis_mac_tdata;
    (* mark_debug = "true" *)
    wire       tx_axis_mac_tvalid;
    (* mark_debug = "true" *)
    wire       tx_axis_mac_tlast;
    (* mark_debug = "true" *)
    wire       tx_axis_mac_tready;

    reg         reg_vld   = 1'b0;
    reg  [4:0]  reg_addr  = 5'd0;
    reg         reg_write = 1'b0;
    reg  [15:0] reg_wval  = 16'd0;
    wire [15:0] reg_rval;
    wire        reg_ack;

    eth_mac #(1) mac_inst (
        .clk_mac    (clk_mac),
        .clk_phy    (clk_phy),
        .rst_n      (rst_n),
        .mode_straps(3'b111),

        .eth_mdc  (eth_mdc),
        .eth_mdio (eth_mdio),
        .eth_rstn (eth_rstn),
        .eth_crsdv(eth_crsdv),
        .eth_rxerr(eth_rxerr),
        .eth_rxd  (eth_rxd),
        .eth_txen (eth_txen),
        .eth_txd  (eth_txd),
        .eth_clkin(eth_clkin),
        .eth_intn (eth_intn),

        .rx_axis_mac_tdata (rx_axis_mac_tdata),
        .rx_axis_mac_tvalid(rx_axis_mac_tvalid),
        .rx_axis_mac_tlast (rx_axis_mac_tlast),
        .rx_axis_mac_tuser (rx_axis_mac_tuser),

        .tx_axis_mac_tdata (tx_axis_mac_tdata),
        .tx_axis_mac_tvalid(tx_axis_mac_tvalid),
        .tx_axis_mac_tlast (tx_axis_mac_tlast),
        .tx_axis_mac_tready(tx_axis_mac_tready),

        .reg_vld  (reg_vld),
        .reg_addr (reg_addr),
        .reg_write(reg_write),
        .reg_wval (reg_wval),
        .reg_rval (reg_rval),
        .reg_ack  (reg_ack)
    );

    wire [7:0] udp_led;
    wire       unused_rx_axis_ready;
    wire       unused_tx_axis_user;

        /* 
            FPGA Traffic Generator Specific Project instantiations - Leo Serodio
        */
    wire        app_start_send;
    wire [3:0]  app_packet_count;

    assign app_start_send   = btnu_d; // start sending packets
    assign app_packet_count = sw[15:12]; // number of packets


    udp_complete_wrapper udp_stack_inst (
        .clk(clk_mac),
        .rst(!rst_n),

        .rx_axis_tdata (rx_axis_mac_tdata),
        .rx_axis_tvalid(rx_axis_mac_tvalid),
        .rx_axis_tready(unused_rx_axis_ready),
        .rx_axis_tlast (rx_axis_mac_tlast),
        .rx_axis_tuser (rx_axis_mac_tuser),

        .tx_axis_tdata (tx_axis_mac_tdata),
        .tx_axis_tvalid(tx_axis_mac_tvalid),
        .tx_axis_tready(tx_axis_mac_tready),
        .tx_axis_tlast (tx_axis_mac_tlast),
        .tx_axis_tuser (unused_tx_axis_user),

        .led_out(udp_led),
        /*****************************************************************/
        // NEW INSTANTIATIONS HERE ARE FOR PROJECT SPECIFIC USES
        // A FILE CALLED (xxxx.sv) will have other instantiations
        /*     COPY CODE HERE     */
        // FPGA traffic generator new signals
        .start_send(app_start_send),
        .packet_count(app_packet_count)
        /* STOP COPYING CODE HERE */
        /*****************************************************************/
    );

    localparam STATE_RST       = 2'd0;
    localparam STATE_IDLE      = 2'd1;
    localparam STATE_CHECK_REG = 2'd2;

    reg [1:0]  state = STATE_RST;
    reg [1:0]  next_state;
    reg [20:0] count = 21'd0;

    always @(posedge clk_mac) begin
        state <= rst_n ? next_state : STATE_RST;
        count <= count + 21'd1;

        led <= {reg_rval[7:0], udp_led};
    end

    always @* begin
        next_state = state;
        reg_vld    = 1'b0;
        reg_write  = 1'b0;
        reg_addr   = 5'd0;
        reg_wval   = 16'd0;

        case (state)
            STATE_RST: begin
                next_state = STATE_IDLE;
            end

            STATE_IDLE: begin
                if (&count)
                    next_state = STATE_CHECK_REG;
            end

            STATE_CHECK_REG: begin
                reg_vld  = 1'b1;
                reg_addr = sw[4:0];

                if (reg_ack)
                    next_state = STATE_IDLE;
            end

            default: begin
                next_state = STATE_RST;
            end
        endcase
    end

endmodule