`timescale 1 ns / 1 ps

module conv3x3_single_ch (
    input  wire clk,
    input  wire rst,

    input  wire conv_en,
    output reg  done,

    input  wire valid_in,
    output reg  valid_out,

    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,

    input  wire signed [7:0] weight_in,
    input  wire signed [15:0] bias,

    output reg  signed [15:0] out,
    output wire [3:0] mac_step_out
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------
    reg signed [23:0] acc;
    reg [3:0] mac_step;
    assign mac_step_out = mac_step;

    reg busy;

    // 🔥 FIX: double delay start
    reg start_d, start_dd;

    // 🔥 FIX: weight valid pipeline
    reg signed [7:0] weight_reg;
    reg weight_valid;

    reg [7:0] pixel_sel;

    // ------------------------------------------------------------
    // Start delay (2-cycle alignment)
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            start_d  <= 0;
            start_dd <= 0;
        end else begin
            start_d  <= (conv_en && valid_in && !busy);
            start_dd <= start_d;
        end
    end

    // ------------------------------------------------------------
    // Weight register + valid flag
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            weight_reg   <= 0;
            weight_valid <= 0;
        end else begin
            weight_reg   <= weight_in;
            weight_valid <= 1;   // becomes valid after first cycle
        end
    end

    // ------------------------------------------------------------
    // Pixel selection
    // ------------------------------------------------------------
    always @(*) begin
        case (mac_step)
            4'd0: pixel_sel = p00;
            4'd1: pixel_sel = p01;
            4'd2: pixel_sel = p02;
            4'd3: pixel_sel = p10;
            4'd4: pixel_sel = p11;
            4'd5: pixel_sel = p12;
            4'd6: pixel_sel = p20;
            4'd7: pixel_sel = p21;
            4'd8: pixel_sel = p22;
            default: pixel_sel = 8'd0;
        endcase
    end

    // ------------------------------------------------------------
    // Main logic (FIXED)
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            acc       <= 0;
            mac_step  <= 0;
            busy      <= 0;
            out       <= 0;
            valid_out <= 0;
            done      <= 0;
        end else begin
            valid_out <= 0;
            done      <= 0;

            // 🔥 Start ONLY when weight is valid
            if (start_dd && weight_valid) begin
                busy     <= 1;
                acc      <= 0;
                mac_step <= 0;
            end

            // MAC
            if (busy) begin
                acc <= acc + (($signed({1'b0, pixel_sel}) * weight_reg) >>> 7);

                `ifndef SYNTHESIS
                $display("[CONV] step=%0d pixel=%0d weight=%0d acc=%0d",
                          mac_step, pixel_sel, weight_reg, acc);
                `endif

                if (mac_step == 4'd8) begin
                    out       <= acc[15:0] + bias;
                    valid_out <= 1;
                    done      <= 1;
                    busy      <= 0;
                    mac_step  <= 0;
                end else begin
                    mac_step <= mac_step + 1;
                end
            end
        end
    end

endmodule
