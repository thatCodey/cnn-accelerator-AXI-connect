`timescale 1 ns / 1 ps

module image_bram (
    input  wire        clk,

    // Write port
    input  wire        we,
    input  wire [11:0] write_addr,
    input  wire [7:0]  write_data,

    // Read port
    input  wire [11:0] read_addr,
    output reg  [7:0]  read_data
);

    // ------------------------------------------------------------
    // Memory
    // ------------------------------------------------------------
    reg [7:0] mem [0:4095];

    integer i;

    // ------------------------------------------------------------
    // Load image
    // ------------------------------------------------------------
    initial begin
        $display("Loading IMAGE...");
        $readmemh("image.mem", mem);

        #1;
        $display("DEBUG IMG[0] = %d", mem[0]);
        $display("DEBUG IMG[1] = %d", mem[1]);
    end

    // ------------------------------------------------------------
    // Write
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (we) begin
            mem[write_addr] <= write_data;
        end
    end

    // ------------------------------------------------------------
    // Read
    // ------------------------------------------------------------
    always @(posedge clk) begin
        read_data <= mem[read_addr];
    end

endmodule
