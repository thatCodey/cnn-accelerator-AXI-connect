`timescale 1 ns / 1 ps

module fc_weight_rom (
    input  wire        clk,
    input  wire [0:0]  addr,
    output reg  signed [7:0]  weight_out,
    output reg  signed [15:0] bias_out
);

    // ------------------------------------------------------------
    // Combined memory (weight + bias)
    // ------------------------------------------------------------
    reg signed [15:0] mem [0:1];   // 2 entries

    integer i;

    // ------------------------------------------------------------
    // Load from file
    // ------------------------------------------------------------
    initial begin
        $display("Loading FC weights + bias...");
        $readmemh("fc_weights.mem", mem);

        #1;
        $display("DEBUG FC weight = %d", mem[0]);
        $display("DEBUG FC bias   = %d", mem[1]);
    end

    // ------------------------------------------------------------
    // Output logic
    // ------------------------------------------------------------
    always @(posedge clk) begin
        weight_out <= $signed(mem[0][7:0]);   // lower 8 bits
        bias_out   <= mem[1];                 // full 16-bit bias
    end

endmodule
