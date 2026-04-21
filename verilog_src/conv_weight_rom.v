// ============================================================================
// File: conv_weight_rom.v
// Description:
//   ROM for convolution weights: 3x3 kernel, 1 input channel, 8 filters.
//   Total weights = 3 * 3 * 1 * 8 = 72
//
// Address Mapping (IMPORTANT):
//   addr = filter_index * 9 + kernel_index
//
//   kernel_index mapping (within each filter):
//     0 -> p00   1 -> p01   2 -> p02
//     3 -> p10   4 -> p11   5 -> p12
//     6 -> p20   7 -> p21   8 -> p22
//
// Example:
//   filter_index = 0, kernel_index = 0  -> addr = 0
//   filter_index = 0, kernel_index = 8  -> addr = 8
//   filter_index = 1, kernel_index = 0  -> addr = 9
//   filter_index = 7, kernel_index = 8  -> addr = 71
//
// Notes:
//   - All weights are initialized to +1 for temporary testing.
//   - Later, replace initialization with $readmemh/$readmemb
//     using trained weights without changing RTL.
// ============================================================================
`timescale 1 ns / 1 ps

module conv_weight_rom (
    input  wire        clk,
    input  wire [6:0]  addr,
    output reg  signed [7:0] weight_out
);

    reg signed [7:0] weight_mem [0:71];

    integer i;

    initial begin
        $display("Loading CONV weights...");

        // 🔥 FORCE initialize (no dependency on mem file)
        for (i = 0; i < 72; i = i + 1) begin
            weight_mem[i] = i;   // unique values for debug
        end

        #1;
        $display("DEBUG CONV[0] = %d", weight_mem[0]);
        $display("DEBUG CONV[1] = %d", weight_mem[1]);
    end

    always @(posedge clk) begin
        weight_out <= weight_mem[addr];
    end

endmodule
