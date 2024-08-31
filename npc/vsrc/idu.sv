`include "macro.vh"
`include "opcode.vh"

module ysyx_22040000_IDU #(
    parameter DWIDTH = 32,
    parameter RF_AWIDTH = 5
) (
    input [DWIDTH-1:0] inst,

    // Next PC
    output [`BRANCH_TYPE_WIDTH-1:0] branch_type,
    output [`NPC_TYPE_WIDTH-1:0] npc_type,

    // RF
    output [RF_AWIDTH-1:0] rd,
    output [RF_AWIDTH-1:0] rs1,
    output [RF_AWIDTH-1:0] rs2,
    output rf_wen,
    // Write Back
    output [`WB_TYPE_WIDTH-1:0] wb_type,

    // Immediate
    output [DWIDTH-1:0] imm,

    // ALU
    output [`A_SEL_LEN-1:0] a_sel,
    output [`B_SEL_LEN-1:0] b_sel,
    output [`ALUOP_WIDTH-1:0] alu_sel,

    // Mem
    output [`STR_TYPE_WIDTH-1:0] str_type,
    output [`LD_TYPE_WIDTH-1:0] ld_type
);
    // Next PC
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`OPC_NUM),
        .KEY_LEN(`OPC_LEN),
        .DATA_LEN(`NPC_TYPE_WIDTH)
    ) npc_type_mux (
        .out(npc_type),
        .key(inst[6:0]),
        .default_out({`NPC_TYPE_WIDTH{1'bx}}),
        .lut({
            `OPC_CSR      , {`NPC_TYPE_WIDTH{1'bx}}, // TODO
            `OPC_LUI      , `NPC_TYPE_STATIC,
            `OPC_AUIPC    , `NPC_TYPE_STATIC,
            `OPC_JAL      , `NPC_TYPE_FORCE,
            `OPC_JALR     , `NPC_TYPE_FORCE,
            `OPC_BRANCH   , `NPC_TYPE_BRANCH,
            `OPC_STORE    , `NPC_TYPE_STATIC,
            `OPC_LOAD     , `NPC_TYPE_STATIC,
            `OPC_ARI_RTYPE, `NPC_TYPE_STATIC,
            `OPC_ARI_ITYPE, `NPC_TYPE_STATIC
        })
    );

    assign branch_type = (inst[6:0] == `OPC_BRANCH) ?
                         inst[14:12] : {`BRANCH_TYPE_WIDTH{1'bx}};



    // Instruction type
    wire [`INST_TYPE_WIDTH-1:0] inst_type;
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`OPC_NUM),
        .KEY_LEN(`OPC_LEN),
        .DATA_LEN(`INST_TYPE_WIDTH)
    ) inst_type_mux (
        .out(inst_type),
        .key(inst[6:0]),
        .default_out({`INST_TYPE_WIDTH{1'bx}}),
        .lut({
            `OPC_CSR      , {`INST_TYPE_WIDTH{1'bx}}, // TODO
            `OPC_LUI      , `U_TYPE,
            `OPC_AUIPC    , `U_TYPE,
            `OPC_JAL      , `J_TYPE,
            `OPC_JALR     , `I_TYPE,
            `OPC_BRANCH   , `B_TYPE,
            `OPC_STORE    , `S_TYPE,
            `OPC_LOAD     , `I_TYPE,
            `OPC_ARI_RTYPE, `R_TYPE,
            `OPC_ARI_ITYPE, `I_TYPE
        })
    );



    // RF
    assign rd = inst[11:7];
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`INST_TYPE_NUM),
        .KEY_LEN(`INST_TYPE_WIDTH),
        .DATA_LEN(1)
    ) rf_wen_mux (
        .out(rf_wen),
        .key(inst_type),
        .default_out(1'b0),
        .lut({
            `R_TYPE, 1'b1,
            `I_TYPE, 1'b1,
            `S_TYPE, 1'b0,
            `B_TYPE, 1'b0,
            `U_TYPE, 1'b1,
            `J_TYPE, 1'b1
        })
    );

    // Write Back
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`OPC_NUM),
        .KEY_LEN(`OPC_LEN),
        .DATA_LEN(`WB_TYPE_WIDTH)
    ) wb_type_mux (
        .out(wb_type),
        .key(inst[6:0]),
        .default_out({`WB_TYPE_WIDTH{1'bx}}),
        .lut({
            `OPC_CSR      , {`WB_TYPE_WIDTH{1'bx}}, // TODO
            `OPC_LUI      , `WB_TYPE_ALU,
            `OPC_AUIPC    , `WB_TYPE_ALU,
            `OPC_JAL      , `WB_TYPE_SNPC,
            `OPC_JALR     , `WB_TYPE_SNPC,
            `OPC_BRANCH   , {`WB_TYPE_WIDTH{1'bx}},
            `OPC_STORE    , {`WB_TYPE_WIDTH{1'bx}},
            `OPC_LOAD     , `WB_TYPE_MEM,
            `OPC_ARI_RTYPE, `WB_TYPE_ALU,
            `OPC_ARI_ITYPE, `WB_TYPE_ALU
        })
    );



    // Immediate generator
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`IMM_TYPE_NUM),
        .KEY_LEN(`IMM_TYPE_WIDTH),
        .DATA_LEN(DWIDTH)
    ) imm_gen_mux (
        .out(imm),
        .key(inst_type),
        .default_out({DWIDTH{1'bx}}),
        .lut({
            `I_TYPE, {{21{inst[31]}}, inst[30:20]},
            `S_TYPE, {{21{inst[31]}}, inst[30:25], inst[11:7]},
            `B_TYPE, {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0},
            `U_TYPE, {inst[31:12], 12'b0},
            `J_TYPE, {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0}
        })
    );



    // ALU
    wire [`ALUOP_WIDTH-1:0] alu_sel_ari;
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`INST_TYPE_NUM),
        .KEY_LEN(`INST_TYPE_WIDTH),
        .DATA_LEN(`ALUOP_WIDTH)
    ) alu_sel_mux (
        .out(alu_sel),
        .key(inst_type),
        .default_out({`ALUOP_WIDTH{1'bx}}),
        .lut({
            `R_TYPE, alu_sel_ari,
            `I_TYPE, alu_sel_ari,
            `S_TYPE, `ALU_ADD,
            `B_TYPE, `ALU_ADD,
            `U_TYPE, (inst[6:0] == `OPC_LUI) ? `ALU_B : `ALU_ADD,
            `J_TYPE, `ALU_ADD
        })
    );

    ysyx_22040000_MuxKey #(
        .NR_KEY(8),
        .KEY_LEN(3),
        .DATA_LEN(`ALUOP_WIDTH)
    ) alu_sel_ari_mux (
        .out(alu_sel_ari),
        .key(inst[14:12]),
        .lut({
            `FNC_ADD_SUB, (inst[30] == 0) ? `ALU_ADD : `ALU_SUB,
            `FNC_SLL    , `ALU_SLL,
            `FNC_SLT    , `ALU_SLT,
            `FNC_SLTU   , `ALU_SLTU,
            `FNC_XOR    , `ALU_XOR,
            `FNC_OR     , `ALU_OR,
            `FNC_AND    , `ALU_AND,
            `FNC_SRL_SRA, (inst[30] == 0) ? `ALU_SRL : `ALU_SRA
        })
    );

    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(`INST_TYPE_NUM),
        .KEY_LEN(`INST_TYPE_WIDTH),
        .DATA_LEN(`A_SEL_LEN)
    ) a_sel_mux (
        .out(a_sel),
        .key(inst_type),
        .default_out(1'b0),
        .lut({
            `R_TYPE, `A_REG,
            `I_TYPE, `A_REG,
            `S_TYPE, `A_REG,
            `B_TYPE, `A_PC,
            `U_TYPE, `A_PC,
            `J_TYPE, `A_PC
        })
    );

    assign b_sel = (inst_type == `R_TYPE) ? `B_REG : `B_IMM;


    // Mem
    // load type: lb, lh, lw, lbu, lhu
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(5),
        .KEY_LEN(3 + 7),
        .DATA_LEN(`LD_TYPE_WIDTH)
    ) ld_type_mux (
        .out(ld_type),
        .key({inst[14:12], inst[6:0]}),
        .default_out({`LD_TYPE_WIDTH{1'bx}}),
        .lut({
            {`FNC_LB , `OPC_LOAD}, `LD_TYPE_LB,
            {`FNC_LH , `OPC_LOAD}, `LD_TYPE_LH,
            {`FNC_LW , `OPC_LOAD}, `LD_TYPE_LW,
            {`FNC_LBU, `OPC_LOAD}, `LD_TYPE_LBU,
            {`FNC_LHU, `OPC_LOAD}, `LD_TYPE_LHU
        })
    );

    // store type: sb, sh, sw
    ysyx_22040000_MuxKeyWithDefault #(
        .NR_KEY(3),
        .KEY_LEN(3 + 7),
        .DATA_LEN(`STR_TYPE_WIDTH)
    ) str_type_mux (
        .out(str_type),
        .key({inst[14:12], inst[6:0]}),
        .default_out({`STR_TYPE_WIDTH{1'bx}}),
        .lut({
            {`FNC_SB, `OPC_STORE}, `STR_TYPE_SB,
            {`FNC_SH, `OPC_STORE}, `STR_TYPE_SH,
            {`FNC_SW, `OPC_STORE}, `STR_TYPE_SW
        })
    );

endmodule
