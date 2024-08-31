`ifndef VSRC_MACRO_VH
`define VSRC_MACRO_VH


`define INST_TYPE_NUM     6
`define INST_TYPE_WIDTH   $clog2(`INST_TYPE_NUM)

`define R_TYPE            3'b000
`define I_TYPE            3'b001
`define S_TYPE            3'b010
`define B_TYPE            3'b011
`define U_TYPE            3'b100
`define J_TYPE            3'b101

// ***** Immediate *****
`define IMM_TYPE_NUM      5
`define IMM_TYPE_WIDTH    $clog2(`IMM_TYPE_NUM)

// `define IMM_I             3'b001
// `define IMM_S             3'b010
// `define IMM_B             3'b011
// `define IMM_U             3'b100
// `define IMM_J             3'b101

// ***** ALU *****
`define ALUOP_NUM          12
`define ALUOP_WIDTH        $clog2(`ALUOP_NUM)

`define ALU_ADD            4'b0000
`define ALU_SUB            4'b0001
`define ALU_AND            4'b0010
`define ALU_OR             4'b0011
`define ALU_XOR            4'b0100
`define ALU_SLL            4'b0101  // Shift Left Logical
`define ALU_SRL            4'b0110  // Shift Right Logical
`define ALU_SRA            4'b0111  // Shift Right Arithmetic
`define ALU_SLT            4'b1000  // Set Less Than
`define ALU_SLTU           4'b1001  // Set Less Than Unsigned
`define ALU_A              4'b1010  // A input
`define ALU_B              4'b1011  // B input

// ***** ALU Input *****
`define A_SEL_NUM          2
`define A_SEL_LEN          $clog2(`A_SEL_NUM)
`define A_REG              1'b0
`define A_PC               1'b1
`define B_SEL_NUM          2
`define B_SEL_LEN          $clog2(`B_SEL_NUM)
`define B_REG              1'b0
`define B_IMM              1'b1

// ***** Load/Store *****
`define LD_TYPE_NUM      5
`define LD_TYPE_WIDTH    $clog2(`LD_TYPE_NUM)

/* func3[2:0] */
`define LD_TYPE_LB       3'b000
`define LD_TYPE_LH       3'b001
`define LD_TYPE_LW       3'b010
`define LD_TYPE_LBU      3'b100
`define LD_TYPE_LHU      3'b101
                           
`define STR_TYPE_NUM     3
`define STR_TYPE_WIDTH   $clog2(`STR_TYPE_NUM)

/* func3[1:0] */
`define STR_TYPE_SB      2'b00
`define STR_TYPE_SH      2'b01
`define STR_TYPE_SW      2'b10


// ***** Write Back *****
`define WB_TYPE_NUM      3
`define WB_TYPE_WIDTH    $clog2(`WB_TYPE_NUM)

`define WB_TYPE_MEM      2'b00
`define WB_TYPE_ALU      2'b01
`define WB_TYPE_SNPC     2'b10

// ***** Next PC *****
`define NPC_TYPE_NUM     3
`define NPC_TYPE_WIDTH   $clog2(`NPC_TYPE_NUM)

`define NPC_TYPE_STATIC  2'b00
`define NPC_TYPE_BRANCH  2'b01
`define NPC_TYPE_FORCE   2'b10

// ***** Branch *****
`define BRANCH_TYPE_NUM   6
`define BRANCH_TYPE_WIDTH $clog2(`BRANCH_TYPE_NUM)

// func3[2:0]
`define BRANCH_EQ        3'b000
`define BRANCH_NE        3'b001
`define BRANCH_LT        3'b100
`define BRANCH_GE        3'b101
`define BRANCH_LTU       3'b110
`define BRANCH_GEU       3'b111


`endif
