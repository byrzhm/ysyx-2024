`include "opcode.vh"
`include "macro.vh"

import "DPI-C" function void halt();

module top #(
    parameter RESET_PC = 32'h80000000,
    parameter DWIDTH = 32
) (
    input clk,
    input rst,
    input [DWIDTH-1:0] inst,
    output [DWIDTH-1:0] pc
);

  always @(posedge clk) begin
    if (inst == `INST_EBREAK) begin
      $display("Exited Successfully");
      halt();
    end
  end

  // ***** PC *****

  wire [DWIDTH-1:0] npc;

  ysyx_22040000_REGISTER_R #(
      .N(DWIDTH),
      .INIT(RESET_PC)
  ) pc_reg (
    .q(pc),
    .d(npc),
    .clk(clk),
    .rst(rst)
  );

  wire [DWIDTH-1:0] snpc = pc + 4;

  // ***** IFU *****

  // ysyx_22040000_IFU (
  //   .pc(pc),
  //   .inst(inst)
  // );

  // ***** RF *****

  localparam RF_AWIDTH = 5;

  wire rf_wen;
  wire [RF_AWIDTH-1:0] rf_waddr, rf_raddr1, rf_raddr2;
  wire [DWIDTH-1:0] rf_wdata, rf_rdata1, rf_rdata2;

  ysyx_22040000_RegisterFile #(
    .AWIDTH(RF_AWIDTH),
    .DWIDTH(DWIDTH)
  ) rf (
    .clk(clk),
    .wen(rf_wen),
    .wdata(rf_wdata),
    .waddr(rf_waddr),
    .raddr1(rf_raddr1),
    .raddr2(rf_raddr2),
    .rdata1(rf_rdata1),
    .rdata2(rf_rdata2)
  );

  // ***** IDU *****

  wire [`BRANCH_TYPE_WIDTH-1:0] branch_type;
  wire [`NPC_TYPE_WIDTH-1:0] npc_type;
  wire [`WB_TYPE_WIDTH-1:0] wb_type;
  wire [DWIDTH-1:0] imm;
  wire [`A_SEL_LEN-1:0] a_sel;
  wire [`B_SEL_LEN-1:0] b_sel;
  wire [`ALUOP_WIDTH-1:0] alu_sel;
  wire [`STR_TYPE_WIDTH-1:0] str_type;
  wire [`LD_TYPE_WIDTH-1:0] ld_type;

  ysyx_22040000_IDU #(
    .DWIDTH(DWIDTH),
    .RF_AWIDTH(RF_AWIDTH)
  ) idu (
    .inst(inst),
    .branch_type(branch_type),
    .npc_type(npc_type),
    .rd(rf_waddr),
    .rs1(rf_raddr1),
    .rs2(rf_raddr2),
    .rf_wen(rf_wen),
    .wb_type(wb_type),
    .imm(imm),
    .a_sel(a_sel),
    .b_sel(b_sel),
    .alu_sel(alu_sel),
    .str_type(str_type),
    .ld_type(ld_type)
  );


  // ***** EXU *****

  wire [DWIDTH-1:0] alu_out;
  wire unsigned_compare;
  wire compare_equare, compare_less_than;

  ysyx_22040000_EXU #(
    .DWIDTH(DWIDTH)
  ) exu (
    .reg_rs1(rf_rdata1),
    .reg_rs2(rf_rdata2),
    .pc(pc),
    .imm(imm),
    .a_sel(a_sel),
    .b_sel(b_sel),
    .alu_sel(alu_sel),
    .alu_out(alu_out),
    .unsigned_compare(unsigned_compare),
    .compare_equare(compare_equare),
    .compare_less_than(compare_less_than)
  );

  // ***** MEM *****

  localparam MEM_AWIDTH = 10;
  wire [DWIDTH/8-1:0] mem_wbe;
  wire [MEM_AWIDTH-1:0] mem_raddr, mem_waddr;
  wire [DWIDTH-1:0] mem_rdata, mem_wdata;
  wire [DWIDTH-1:0] mem_out;

  ysyx_22040000_MEM #(
    .AWIDTH(MEM_AWIDTH),
    .DWIDTH(DWIDTH)
  ) memory (
    .clk(clk),
    .wbe(mem_wbe),
    .waddr(mem_waddr),
    .wdata(mem_wdata),
    .raddr(mem_raddr),
    .rdata(mem_rdata)
  );

  wire [1:0] mem_addr_offset = alu_out[1:0];
  // wire [DWIDTH/8-1:0] mem_wbe_sb, mem_wbe_sh, mem_wbe_sw;

  // assign mem_wbe_sb = {{DWIDTH/8-1{1'b0}}, 1'b1} << mem_addr_offset;
  // assign mem_wbe_sh = {{DWIDTH/8-2{1'b0}}, 2'b11} << mem_addr_offset;
  // assign mem_wbe_sw = {DWIDTH/8{1'b1}};

  ysyx_22040000_MuxKeyWithDefault #(
    .NR_KEY(`STR_TYPE_NUM),
    .KEY_LEN(`STR_TYPE_WIDTH),
    .DATA_LEN(DWIDTH/8)
  ) mem_wbe_mux (
    .out(mem_wbe),
    .key(str_type),
    .default_out({DWIDTH/8{1'b0}}),
    .lut({
      `STR_TYPE_SB , {{DWIDTH/8-1{1'b0}}, 1'b1} << mem_addr_offset,
      `STR_TYPE_SH , {{DWIDTH/8-2{1'b0}}, 2'b11} << mem_addr_offset,
      `STR_TYPE_SW , {DWIDTH/8{1'b1}}
    })
  );

  assign mem_waddr = alu_out[2 +: MEM_AWIDTH];
  assign mem_raddr = alu_out[2 +: MEM_AWIDTH];
  assign mem_wdata = rf_rdata2 << (mem_addr_offset * 8);

  ysyx_22040000_MuxKeyWithDefault #(
    .NR_KEY(`LD_TYPE_NUM),
    .KEY_LEN(`LD_TYPE_WIDTH),
    .DATA_LEN(DWIDTH)
  ) mem_out_mux (
    .out(mem_out),
    .key(ld_type),
    .default_out({DWIDTH{1'bx}}),
    .lut({
      `LD_TYPE_LB, {{DWIDTH-8{mem_raddr[mem_addr_offset * 8 + 7]}}, mem_rdata[mem_addr_offset * 8 +: 8]},
      `LD_TYPE_LH, {{DWIDTH-16{mem_raddr[mem_addr_offset * 8 + 15]}}, mem_rdata[mem_addr_offset * 8 +: 16]},
      `LD_TYPE_LW, mem_rdata,
      `LD_TYPE_LBU, {{DWIDTH-8{1'b0}}, mem_rdata[mem_addr_offset * 8 +: 8]},
      `LD_TYPE_LHU, {{DWIDTH-16{1'b0}}, mem_rdata[mem_addr_offset * 8 +: 16]}
    })
  );

  // ***** Write Back *****

  ysyx_22040000_MuxKeyWithDefault #(
    .NR_KEY(`WB_TYPE_NUM),
    .KEY_LEN(`WB_TYPE_WIDTH),
    .DATA_LEN(DWIDTH)
  ) rf_wdata_mux (
    .out(rf_wdata),
    .key(wb_type),
    .default_out({DWIDTH{1'bx}}),
    .lut({
        `WB_TYPE_MEM , mem_out,
        `WB_TYPE_ALU , alu_out,
        `WB_TYPE_SNPC, snpc
    })
  );

  // ***** Next PC *****

  wire branch_taken;
  ysyx_22040000_MuxKeyWithDefault #(
    .NR_KEY(`BRANCH_TYPE_NUM),
    .KEY_LEN(`BRANCH_TYPE_WIDTH),
    .DATA_LEN(1)
  ) branch_taken_mux (
    .out(branch_taken),
    .key(branch_type),
    .default_out(1'b0), // not taken
    .lut({
      `BRANCH_EQ , compare_equare,
      `BRANCH_NE , ~compare_equare,
      `BRANCH_LT , compare_less_than,
      `BRANCH_GE , ~compare_less_than,
      `BRANCH_LTU, compare_less_than,
      `BRANCH_GEU, ~compare_less_than
    })
  );

  ysyx_22040000_MuxKeyWithDefault #(
    .NR_KEY(`BRANCH_TYPE_NUM),
    .KEY_LEN(`BRANCH_TYPE_WIDTH),
    .DATA_LEN(1)
  ) unsigned_compare_mux (
    .out(unsigned_compare),
    .key(branch_type),
    .default_out(1'b0), // signed compare
    .lut({
      `BRANCH_EQ , 1'b0,
      `BRANCH_NE , 1'b0,
      `BRANCH_LT , 1'b0,
      `BRANCH_GE , 1'b0,
      `BRANCH_LTU, 1'b1,
      `BRANCH_GEU, 1'b1
    })
  );

  ysyx_22040000_MuxKeyWithDefault #(
    .NR_KEY(`NPC_TYPE_NUM),
    .KEY_LEN(`NPC_TYPE_WIDTH),
    .DATA_LEN(DWIDTH)
  ) npc_mux (
    .out(npc),
    .key(npc_type),
    .default_out({DWIDTH{1'bx}}),
    .lut({
      `NPC_TYPE_STATIC, snpc,
      `NPC_TYPE_BRANCH, (branch_taken) ? alu_out : snpc,
      `NPC_TYPE_FORCE , alu_out
    })
  );

endmodule
