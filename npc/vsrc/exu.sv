`include "macro.vh"

module ysyx_22040000_EXU #(
    parameter DWIDTH = 32
) (
    input [DWIDTH-1:0] reg_rs1,
    input [DWIDTH-1:0] reg_rs2,
    input [DWIDTH-1:0] pc,
    input [DWIDTH-1:0] imm,

    input [`A_SEL_LEN-1:0] a_sel,
    input [`B_SEL_LEN-1:0] b_sel,

    input [`ALUOP_WIDTH-1:0] alu_sel,
    output [DWIDTH-1:0] alu_out,

    input unsigned_compare,
    output compare_equare,
    output compare_less_than
);

    // branch comparator
    assign compare_equare = (reg_rs1 == reg_rs2);
    assign compare_less_than = (unsigned_compare) ?
                               (reg_rs1 < reg_rs2)
                             : ($signed(reg_rs1) < $signed(reg_rs2));

    wire [DWIDTH-1:0] a, b;

    ysyx_22040000_MuxKey #(
        .NR_KEY(`A_SEL_NUM),
        .KEY_LEN(`A_SEL_LEN),
        .DATA_LEN(DWIDTH)
    ) a_mux (
        .out(a),
        .key(a_sel),
        .lut({
            `A_REG, reg_rs1,
            `A_PC , pc
        })
    );

    ysyx_22040000_MuxKey #(
        .NR_KEY(`B_SEL_NUM),
        .KEY_LEN(`B_SEL_LEN),
        .DATA_LEN(DWIDTH)
    ) b_mux (
        .out(b),
        .key(b_sel),
        .lut({
            `B_REG, reg_rs2,
            `B_IMM, imm
        })
    );

    ysyx_22040000_ALU #(
        .DWIDTH(DWIDTH)
    ) alu (
        .a(a),
        .b(b),
        .sel(alu_sel),
        .out(alu_out)
    );

endmodule
