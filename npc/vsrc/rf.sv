module ysyx_22040000_RegisterFile #(
    parameter AWIDTH = 5,
    parameter DWIDTH = 32
) (
    input clk,
    input wen,

    input [DWIDTH-1:0] wdata,
    input [AWIDTH-1:0] waddr,

    input [AWIDTH-1:0] raddr1,
    input [AWIDTH-1:0] raddr2,
    output [DWIDTH-1:0] rdata1,
    output [DWIDTH-1:0] rdata2
);

    reg [DWIDTH-1:0] mem [2**AWIDTH-1:0];
    wire write_enable = wen & (|waddr);

    integer i;
    initial begin
        for (i = 0; i < 2**AWIDTH; i = i + 1) mem[i] = 0;
    end

    assign rdata1 = mem[raddr1];
    assign rdata2 = mem[raddr2];

    always @(posedge clk)
        if (write_enable) mem[waddr] <= wdata;

    always @(posedge clk) begin
        for (i = 0; i < 2**AWIDTH; i = i + 1) begin
            $display("Reg[%0d] = %0d", i, mem[i]);
        end
    end

endmodule
