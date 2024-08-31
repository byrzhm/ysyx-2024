`include "macro.vh"

module ysyx_22040000_ALU #(
    parameter DWIDTH = 32
) (
    input [`ALUOP_WIDTH-1:0] sel,
    input [DWIDTH-1:0] a,
    input [DWIDTH-1:0] b,
    output [DWIDTH-1:0] out
);

  ysyx_22040000_MuxKeyWithDefault #(
      .NR_KEY  (`ALUOP_NUM),
      .KEY_LEN (`ALUOP_WIDTH),
      .DATA_LEN(DWIDTH)
  ) mux (
    .out(out),
    .key(sel),
    .default_out({DWIDTH{1'bx}}),
    .lut({
        `ALU_ADD , a + b,
        `ALU_SUB , a - b,
        `ALU_AND , a & b,
        `ALU_OR  , a | b,
        `ALU_XOR , a ^ b,
        `ALU_SLL , a << b[4:0],
        `ALU_SRL , a >> b[4:0],
        `ALU_SRA , $signed(a) >>> b[4:0],
        `ALU_SLT , ($signed(a) < $signed(b)) ? {{DWIDTH-1{1'b0}}, 1'b1} : {DWIDTH{1'b0}},
        `ALU_SLTU, (a < b) ? {{DWIDTH-1{1'b0}}, 1'b1} : {DWIDTH{1'b0}},
        `ALU_A   , a,
        `ALU_B   , b
    })
  );

endmodule
