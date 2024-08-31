module ysyx_22040000_MEM #(
    parameter AWIDTH = 10,
    parameter DWIDTH = 32
) (
    input clk,
    input [DWIDTH/8-1:0] wbe,
    input [AWIDTH-1:0] raddr,
    input [AWIDTH-1:0] waddr,
    input [DWIDTH-1:0] wdata,
    output [DWIDTH-1:0] rdata
);

    reg [DWIDTH-1:0] mem [2**AWIDTH-1:0];

    integer i;
    initial begin
        for (i = 0; i < 2**AWIDTH; i = i + 1)
            mem[i] = 0;
    end

    always @(posedge clk) begin
        for (i = 0; i < DWIDTH/8; i = i + 1) begin
            if (wbe[i])
                mem[waddr][i*8 +: 8] <= wdata[i*8 +: 8];
        end
    end

    assign rdata = mem[raddr];

endmodule
