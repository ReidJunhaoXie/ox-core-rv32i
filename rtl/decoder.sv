import core_pkg::*;

module decoder (
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic        funct7,
    output jp_t         jp,
    output logic        branch,
    output imme_src_t   imme_src,
    output logic        rf_wen,
    output logic        dmem_wen,
    output rf_rd_src_t  rf_rd_src,
    output alub_src_t   alub_src,
    
    output logic [3:0]  alu_ctrl

    // input logic [1:0]  alu_op   // for test
) ; 
    logic   [1:0]   alu_op ;
    
    always_comb begin : main_decoder
        // default : R-type disable rf write
        jp = PC_ADD4 ; branch = 1'b0 ; imme_src = IMM_I ; rf_wen = 1'b0 ; dmem_wen = 1'b0 ; 
        rf_rd_src = RD_ALU ; alub_src = ALUB_RF ; alu_op = 2'b10 ; 

        case (opcode)              // {jp,branch,imme_src,rf_wen,dmem_wen,rf_rd_src,alub_src,alu_op}
            OP_R_TYPE: begin
                rf_wen = 1'b1 ; imme_src = imme_src_t'(3'bxxx) ; // 13'b00_0_xxx_1_0_00_0_10;  R-type 
            end 
            OP_I_TYPE: begin
                rf_wen = 1'b1 ; alub_src = ALUB_IMME ; // 13'b00_0_000_1_0_00_1_10;  I-type except for load and jalr
            end
            OP_LOAD  : begin
                rf_wen = 1'b1 ; rf_rd_src = RD_DM ; alub_src = ALUB_IMME ; alu_op = 2'b00 ; // 13'b00_0_000_1_0_01_1_00;  I-load
            end        
            OP_JALR  : begin
                jp = PC_ALU ; rf_wen = 1'b1 ; rf_rd_src = RD_PC ; alub_src = ALUB_IMME ; alu_op = 2'b00 ;
            end // 13'b10_0_011_1_0_10_1_00;  I-jalr
            OP_STORE : begin
                imme_src = IMM_S ; dmem_wen = 1'b1 ; rf_rd_src = rf_rd_src_t'(2'bxx) ; alub_src = ALUB_IMME ; alu_op = 2'b00 ;
            end // 13'b00_0_001_0_1_xx_1_00;  S-type
            OP_BRANCH: begin
                jp = PC_ADDI ; branch = 1'b1 ; imme_src = IMM_B ; rf_rd_src = rf_rd_src_t'(2'bxx); alub_src = ALUB_RF ; alu_op = 2'b01 ;
            end // 13'b00_1_010_0_0_xx_0_01;  B-type
            OP_JAL   : begin
                jp = PC_ADDI ; imme_src = IMM_J ; rf_wen = 1'b1 ; rf_rd_src = RD_PC ; alub_src = alub_src_t'(1'bx) ; alu_op = 2'bxx ;
            end // 13'b01_0_011_1_0_10_x_xx;  J-type
            // OP_LUI: ; lui
            // OP_AUIPC: ; auipc
            default  : begin
                jp = PC_ADD4 ; branch = 1'b0 ; imme_src = IMM_I ; rf_wen = 1'b0 ; dmem_wen = 1'b0 ; 
                rf_rd_src = RD_ALU ; alub_src = ALUB_RF ; alu_op = 2'b10 ; 
            end
        endcase
    end
    
    // alu_decoder
  
    assign alu_ctrl[2:0]    = alu_op[1] ? funct3 : 3'b000 ;
    assign alu_ctrl[3]      = (alu_op[1]&funct7&opcode[5])|alu_op[0] ; 
    
endmodule