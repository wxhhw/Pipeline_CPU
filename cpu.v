`include "alu.v"
`include "ctrl_unit.v"
`include "DM.v"
`include "EXT.v"
`include "IF_ID.v"
`include "ID_EXE.v"
`include "EXE_MEM.v"
`include "MEM_WB.v"
`include "ForwardingUnit.v"
`include "IM.v"
`include "mux.v"
`include "NPC.v"
`include "PC.v"
`include "RF.v"
`include "ctrl_encode_def.v"

module cpu( clk, rst );

    input           clk;
    input           rst;

//-------------------------IF Stage-----------------------------

    //PC & NPC
    wire    [31:0]  pc;
    wire    [31:0]  npc;
    wire            PC_stall;

    assign PC_stall = 1'b0;

    PC      PC      ( .clk(clk), .rst(rst), .stall(PC_stall), .npc(npc), .pc(pc) );


    //IM
    wire    [31:0] ins;
    IM      IM      ( .pc(pc), .ins(ins) );

    //IF_ID
    wire    IFID_stall;
    wire    IFID_flush;

    assign IFID_stall = 1'b0;
    assign IFID_stall = 1'b0;

    wire    [31:0]   IFID_ins;
    wire    [31:0]   IFID_pc;

    IF_ID    IF_ID( .clk(clk), .rst(rst), .IFID_stall(IFID_stall), .IFID_flush(IFID_flush),  //控制信号
                    .pc(pc),   .ins(ins),                                                    //输入
                    .IFID_pc(IFID_pc),    .IFID_ins(IFID_ins));                              //输出



//-------------------------ID Stage-----------------------------
    //RF
    wire            MEMWB_RFWr; //WB阶段写信号
    wire [4:0]      MEMWB_rd;   //WB阶段写入寄存器
    wire [31:0]     WD;         //WB阶段写回入数据
    wire [31:0]     RD1;
    wire [31:0]     RD2;

    RF      RF      ( .clk(clk), .rst(rst), 
                      .RFWr(MEMWB_RFWr), .A1(IFID_ins[25:21]), .A2(IFID_ins[20:16]), .A3(MEMWB_rd), .WD(WD),   
                      .RD1(RD1), .RD2(RD2) );
    //EXT
    wire    [1:0]   EXTOp;
    wire    [31:0]  Imm32;
    EXT     EXT     ( .Imm16(IFID_ins[15:0]), .EXTOp(EXTOp), .Imm32(Imm32) );

    //RegDstmux
    wire    [1:0]   RegDst;    
    wire    [31:0]  rd;
    mux4    RegDstmux  ( .d0(IFID_ins[20:16]), .d1(IFID_ins[15:11]), .d2(31), .d3(0), .s(RegDst), .y(rd) );    

    //NPC
    wire    [2:0]   NPCOp;
    NPC     NPC     ( .pc(IFID_pc),    .NPCOp(NPCOp),   .IMM(IFID_ins[25:0]), .Rt(IFID_ins[20:16]), 
                      .RD1(RD1),       .RD2(RD2),       .npc(npc) );

    //ctrl_unit
    wire    [1:0]   DMWr;
    wire    [3:0]   DMRd;
    ctrl_unit ctrl_unit( .opcode(IFID_ins[31:26]), .func(IFID_ins[5:0]), 
                         .RegDst(RegDst),     .NPCOp(NPCOp),    .DMRd(DMRd), .toReg(toReg), 
                         .ALUOp(ALUOp),       .DMWr(DMWr),      .ALUSrc1(ALUSrc1), 
                         .ALUSrc2(ALUSrc2),   .RFWr(RFWr),      .EXTOp(EXTOp) );

    wire            IDEXE_ALUSrc1;
    wire            IDEXE_ALUSrc2;
    wire            IDEXE_RFWr;
    wire    [31:0]  IDEXE_RD1;
    wire    [31:0]  IDEXE_RD2;
    wire    [31:0]  IDEXE_Imm32;
    wire    [31:0]  IDEXE_ins;
    wire    [31:0]  IDEXE_pc;
    wire    [1:0]   IDEXE_RegDst;    //Rt Rd R31
    wire    [2:0]   IDEXE_NPCOp;     
    wire    [3:0]   IDEXE_DMRd;      //lw lh lb lhu lbu
    wire    [1:0]   IDEXE_toReg;     //PC2Reg Mem2Reg ALU2Reg
    wire    [3:0]   IDEXE_ALUOp;     
    wire    [1:0]   IDEXE_DMWr;      //sw sh sb


    ID_EXE  ID_EXE( .clk(clk), .rst(rst), .IDEXE_stall(IDEXE_stall), .IDEXE_flush(IDEXE_flush), //控制信号
                    .RD1(RD1), .RD2(RD2), .rd(rd),  //RF
                    .Imm32(Imm32),                 //EXT
                    .ins(IFID_ins), .pc(IFID_pc), .RegDst(RegDst), .NPCOp(NPCOp), .DMRd(DMRd), .toReg(toReg), .ALUOp(ALUOp), 
                    .DMWr(DMWr), .ALUSrc1(ALUSrc1), .ALUSrc2(ALUSrc2), .RFWr(RFWr),
                    //输出
                    .IDEXE_RD1(IDEXE_RD1), .IDEXE_RD2(IDEXE_RD2), .IDEXE_Imm32(IDEXE_Imm32),   .IDEXE_rd(IDEXE_rd),
                    .IDEXE_ins(IDEXE_ins), .IDEXE_pc(IDEXE_pc),   .IDEXE_RegDst(IDEXE_RegDst), .IDEXE_NPCOp(IDEXE_NPCOp), .IDEXE_DMRd(IDEXE_DMRd), 
                    .IDEXE_toReg(IDEXE_toReg), .IDEXE_ALUOp(IDEXE_ALUOp), .IDEXE_DMWr(IDEXE_DMWr),
                    .IDEXE_ALUSrc1(IDEXE_ALUSrc1), .IDEXE_ALUSrc2(IDEXE_ALUSrc2), .IDEXE_RFWr(IDEXE_RFWr) );






//------------------------EX Stage--------------------------

    //ALUMux_A (reg or shamt)
    wire    [31:0] ALUSrcAout;
    mux2    ALUSrc_A      ( .d0(IDEXE_RD1), .d1({27'b0,IDEXE_ins[10:6]}), 
                            .s(IDEXE_ALUSrc1), .y(ALUSrcAout) );

    //ALU_A forwarding
    wire    [1:0]  ALU_A;
    wire    [31:0] EXEMEM_ALUout;
    wire    [31:0] A;                // ALU input A
    mux4    ALU_A_final   ( .d0(ALUSrcAout), .d1(EXEMEM_ALUout),.d2(WD), .d3(0), //d3 is not used
                            .s(ALU_A),.y(A) );

    //ALUMux_B (reg or Imm32)
    wire    [31:0] ALUSrcBout;
    mux2    ALUSrc_B      ( .d0(IDEXE_RD2), .d1(IDEXE_Imm32), 
                            .s(IDEXE_ALUSrc2), .y(ALUSrcBout) );

    //ALU_B forwarding
    wire    [1:0]  ALU_B;
    wire    [31:0] B;                // ALU input B
    mux4    ALU_B_final   ( .d0(ALUSrcBout), .d1(EXEMEM_ALUout), .d2(WD), .d3(0), //d3 is not used
                            .s(ALU_B),.y(B) );

    //ALU
    wire            Zero;
    wire    [31:0]  ALUout;
    alu      alu    ( .A(A), .B(B), .ALUOp(IDEXE_ALUOp), .C(ALUout), .Zero(Zero) );

    //ForwardingUnit
    wire    EXEMEM_RFWr;
    wire    DMdata_ctrl;
    wire    MEMWB_DMRd;
    wire    EXEMEM_DMWr;
    wire    [4:0] EXEMEM_rd;

    ForwardingUnit ForwardingUnit( .EXEMEM_RFWr(EXEMEM_RFWr),   .EXEMEM_rd(EXEMEM_rd),    .IDEXE_rs(IDEXE_ins[25:21]),
                                   .IDEXE_rt(IDEXE_ins[20:16]), .MEMWB_RFWr(MEMWB_RFWr),  .MEMWB_rd(MEMWB_rd),
                                   .ALU_A(ALU_A),.ALU_B(ALU_B), .DMdata_ctrl(DMdata_ctrl),
                                   .MEMWB_DMRd(MEMWB_DMRd),     .EXEMEM_DMWr(EXEMEM_DMWr));

    wire    [31:0]  EXEMEM_ins;
    wire    [31:0]  EXEMEM_pc;
    wire    [3:0]   EXEMEM_DMRd;      
    wire    [1:0]   EXEMEM_toReg;     //PC2Reg Mem2Reg ALU2Reg
    wire    [31:0]  EXEMEM_DMdata;      

    EXE_MEM EXE_MEM( .clk(clk), .rst(rst),
                     .ins(IDEXE_ins), .pc(IDEXE_pc), .rd(IDEXE_rd), .toReg(IDEXE_toReg), 
                     .DMRd(IDEXE_DMRd), .DMWr(IDEXE_DMWr), .RFWr(IDEXE_RFWr), .DMdata(ALUSrcBout), .ALUout(ALUout),
                     //output
                     .EXEMEM_ins(EXEMEM_ins), .EXEMEM_pc(EXEMEM_pc), .EXEMEM_rd(EXEMEM_rd), .EXEMEM_toReg(EXEMEM_toReg), 
                     .EXEMEM_DMRd(EXEMEM_DMRd), .EXEMEM_DMWr(EXEMEM_DMWr), .EXEMEM_RFWr(EXEMEM_RFWr), 
                     .EXEMEM_DMdata(EXEMEM_DMdata), .EXEMEM_ALUout(EXEMEM_ALUout) );


//-------------------MEM Stage-------------------------------

    //MEM to MEM forwarding
    wire    [31:0]  DMdata;
    mux2    DMdata_mux ( .d0(EXEMEM_DMdata), .d1(WD), .s(DMdata_ctrl), .y(DMdata) );

    //DM
    wire    [31:0]  DMout;
    DM      DM      ( .clk(clk), .DMWr(EXEMEM_DMWr), .DMRd(EXEMEM_DMRd), 
                      .DMaddr(EXEMEM_ALUout), .DMdata(DMdata), .DMout(DMout) );

    //MEMWBReg
    wire    [31:0]  MEMWB_ins;
    wire    [31:0]  MEMWB_pc;
    wire    [31:0]  MEMWB_ALUout;
    wire    [31:0]  MEMWB_DMout;
    wire    [1:0]   MEMWB_toReg;
    MEM_WB  MEM_WB ( .clk(clk), .rst(rst),
                     .ins(EXEMEM_ins), .pc(EXEMEM_pc), .rd(EXEMEM_rd), .toReg(EXEMEM_toReg), 
                     .RFWr(EXEMEM_RFWr), .DMRd(EXEMEM_DMRd), .DMout(EXEMEM_DMout), .ALUout(EXEMEM_ALUout),
                     //output
                     .MEMWB_ins(MEMWB_ins), .MEMWB_pc(MEMWB_pc), .MEMWB_rd(MEMWB_rd), .MEMWB_toReg(MEMWB_toReg), 
                     .MEMWB_DMRd(MEMWB_DMRd), .MEMWB_RFWr(MEMWB_RFWr), .MEMWB_DMout(MEMWB_DMout), .MEMWB_ALUout(MEMWB_ALUout) );


    //--------------------------WB Stage---------------------------------

    //toRegmux (write RF)
    mux4 toRegmux( .d0(MEMWB_ALUout), .d1(MEMWB_DMout), .d2(MEMWB_pc + 4), .d3(0),   //d3 is not used 
                   .s(MEMWB_toReg),   .y (WD));



endmodule