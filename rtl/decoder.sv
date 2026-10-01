import core_pkg::*;

module decoder (
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic        funct7,
    /*output logic [1:0]  jp,
    output logic        branch,
    output logic [2:0]  imme_src,
    output logic        rf_wen,
    output logic        dmem_wen,
    output logic [1:0]  rf_rd_src,
    output logic        alub_src,
    */
    output logic [3:0]  alu_ctrl,

    input logic [1:0]  alu_op   // for test
) ; 
    // logic [1:0] alu_op ;
    /*
    always_comb begin : main_decoder
        case (opcode)                                                 // {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op}
            OP_R_TYPE: {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADD4,1'b0,3'dx ,1'b1,1'b0,RD_ALU,ALUB_RF  ,ALUOP_ARITHEM} ; // 13'b00_0_xxx_1_0_00_0_10;  R-type 
            OP_I_TYPE: {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADD4,1'b0,IMM_I,1'b1,1'b0,RD_ALU,ALUB_IMME,ALUOP_ARITHEM} ; // 13'b00_0_000_1_0_00_1_10;  I-type except for load and jalr
            OP_LOAD  : {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADD4,1'b0,IMM_I,1'b1,1'b0,RD_DM ,ALUB_IMME,ALUOP_MEM}     ; // 13'b00_0_000_1_0_01_1_00;  I-load
            OP_JALR  : {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ALU ,1'b0,IMM_I,1'b1,1'b0,RD_PC ,ALUB_IMME,ALUOP_MEM}     ; // 13'b10_0_011_1_0_10_1_00;  I-jalr
            OP_STORE : {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADD4,1'b0,IMM_S,1'b0,1'b1,2'dx  ,ALUB_IMME,ALUOP_MEM}     ; // 13'b00_0_001_0_1_xx_1_00;  S-type
            OP_BRANCH: {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADDI,1'b1,IMM_B,1'b0,1'b0,2'dx  ,ALUB_RF  ,ALUOP_BRANCH}  ; // 13'b00_1_010_0_0_xx_0_01;  B-type
            OP_JAL   : {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADDI,1'b0,IMM_J,1'b1,1'b0,RD_PC ,1'bx     ,2'bxx}         ; // 13'b01_0_011_1_0_10_x_xx;  J-type
            // OP_LUI: ; lui
            // OP_AUIPC: ; auipc
            default  : {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op} = {PC_ADD4,1'b0,3'dx ,1'b1,1'b0,RD_ALU,ALUB_RF  ,ALUOP_ARITHEM} ;
        endcase
    end
    */
    always_comb begin : alu_decoder
        alu_ctrl[2:0]   = alu_op[1] ? funct3 : 3'b000 ;
        alu_ctrl[3]     = (alu_op[1]&funct7&opcode[5])|alu_op[0] ; 
    end
endmodule