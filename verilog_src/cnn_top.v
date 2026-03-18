`timescale 1ns / 1ps

module cnn_top(
    input  wire clk,
    input  wire rst,
    input  wire start,

    output wire done,
    output wire class_out,
    output wire signed [15:0] final_score,

    // AXI image write interface
    input  wire        img_we,
    input  wire [11:0] img_wr_addr,
    input  wire [7:0]  img_wr_data,

    // Debug ports (required by wrapper)
    output wire [2:0] debug_state,
    output wire [3:0] active_stage
);

    // ============================================================
    // Internal Image BRAM
    // ============================================================

    reg  [11:0] img_rd_addr;
    wire [7:0]  img_pixel;

    image_bram u_img (
        .clk(clk),
        .we(img_we),
        .write_addr(img_wr_addr),
        .write_data(img_wr_data),
        .read_addr(img_rd_addr),
        .read_data(img_pixel)
    );

    // ============================================================
    // FSM
    // ============================================================

    wire conv_en, relu_en, pool_en, gap_en, fc_en;
    wire conv_done, gap_done, fc_done;

    cnn_control_fsm u_fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .conv_done(conv_done),
        .gap_done(gap_done),
        .fc_done(fc_done),
        .conv_en(conv_en),
        .relu_en(relu_en),
        .pool_en(pool_en),
        .gap_en(gap_en),
        .fc_en(fc_en),
        .done(done),
        .debug_state(debug_state)
    );

    assign active_stage =
        conv_en ? 4'b0001 :
        relu_en ? 4'b0010 :
        pool_en ? 4'b0100 :
        gap_en  ? 4'b1000 :
                  4'b0000;

    // ============================================================
    // Address logic
    // ============================================================

    always @(posedge clk) begin
        if (rst)
            img_rd_addr <= 0;
        else if (conv_en)
            img_rd_addr <= img_rd_addr + 1;
        else
            img_rd_addr <= 0;
    end

    // ============================================================
    // Line Buffer
    // ============================================================

    wire lb_valid;
    wire [7:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;

    linebuffer_3x3 u_lb (
        .clk(clk),
        .rst(rst),
        .pixel_in(img_pixel),
        .pixel_valid(conv_en),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .window_valid(lb_valid),
        .dbg_row(),
        .dbg_col()
    );

    // ============================================================
    // Convolution
    // ============================================================

    wire signed [7:0] conv_weight;
    reg  [6:0] conv_weight_addr;

    conv_weight_rom u_conv_rom (
        .clk(clk),
        .addr(conv_weight_addr),
        .weight_out(conv_weight)
    );

    wire signed [15:0] conv_out;
    wire conv_valid;

    conv3x3_single_ch u_conv (
        .clk(clk),
        .rst(rst),
        .conv_en(conv_en),
        .done(conv_done),
        .valid_in(lb_valid),
        .valid_out(conv_valid),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .weight_in(conv_weight),
        .bias(16'sd0),
        .out(conv_out)
    );

    // ============================================================
    // ReLU
    // ============================================================

    wire signed [15:0] relu_out;
    wire relu_valid;

    relu u_relu (
        .clk(clk),
        .rst(rst),
        .in_data(conv_out),
        .valid_in(conv_valid),
        .out_data(relu_out),
        .valid_out(relu_valid)
    );

    // ============================================================
    // GAP
    // ============================================================

    wire signed [15:0] gap_out;
    wire gap_valid;

    global_avg_pool u_gap (
        .clk(clk),
        .rst(rst),
        .gap_en(gap_en),
        .in_data(relu_out),
        .valid_in(relu_valid),
        .out_data(gap_out),
        .valid_out(gap_valid),
        .done(gap_done),
        .dbg_accumulator(),
        .dbg_sample_count()
    );

    // ============================================================
    // FC
    // ============================================================

    wire signed [7:0]  fc_weight;
    wire signed [15:0] fc_bias;

    fc_weight_rom u_fc_rom (
        .clk(clk),
        .addr(0),
        .weight_out(fc_weight),
        .bias_out(fc_bias)
    );

    wire signed [15:0] fc_out;
    wire fc_valid;

    fc_layer u_fc (
        .clk(clk),
        .rst(rst),
        .fc_en(fc_en),
        .in_data(gap_out),
        .valid_in(gap_valid),
        .weight(fc_weight),
        .bias(fc_bias),
        .out(fc_out),
        .valid_out(fc_valid),
        .done(fc_done)
    );

    assign final_score = fc_out;

    threshold #(.THRESHOLD(16'sd0)) u_thresh (
        .clk(clk),
        .rst(rst),
        .valid_in(fc_valid),
        .valid_out(),
        .done(),
        .in_data(fc_out),
        .class_out(class_out)
    );

endmodule
