module decoder 
import core_pkg::*;
(
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic        funct7,

    output jp_t         jp,
    output logic        branch,
    output imme_src_t   imme_src,
    output logic        rf_wen,
    output logic        dm_wen,
    output rf_rd_src_t  rf_rd_src,
    output alub_src_t   alub_src,
    output alua_src_t   alua_src,
    output logic [3:0]  alu_ctrl

    // input logic [1:0]  alu_op   // for test
) ; 
    logic   [1:0]   alu_op ;
    
    always_comb begin : main_decoder
        // default : R-type disable rf write
        jp = JP_ADD4 ; branch = 1'b0 ; imme_src = IMM_I ; rf_wen = 1'b0 ; dm_wen = 1'b0 ; 
        rf_rd_src = RD_ALU ; alub_src = ALUB_RF ; alua_src =  ALUA_RF ; alu_op = 2'b10 ; 

        case (opcode)              // {jp,branch,imme_src,rf_wen,dm_wen,rf_rd_src,alub_src,alu_op}
            OP_R_TYPE: begin
                rf_wen = 1'b1 ; imme_src = imme_src_t'(3'bxxx) ; 
            end 
            OP_I_TYPE: begin
                rf_wen = 1'b1 ; alub_src = ALUB_IMME ; 
            end
            OP_LOAD: begin
                rf_wen = 1'b1 ; rf_rd_src = RD_DM ; alub_src = ALUB_IMME ; alu_op = 2'b00 ; 
            end        
            OP_JALR: begin
                jp = JP_ALU ; rf_wen = 1'b1 ; rf_rd_src = RD_PC ; alub_src = ALUB_IMME ; alu_op = 2'b00 ;
            end 
            OP_STORE: begin
                imme_src = IMM_S ; dm_wen = 1'b1 ; rf_rd_src = rf_rd_src_t'(2'bxx) ; alub_src = ALUB_IMME ; alu_op = 2'b00 ;
            end 
            OP_BRANCH: begin
                jp = JP_ADD4 ; branch = 1'b1 ; imme_src = IMM_B ; rf_rd_src = rf_rd_src_t'(2'bxx); alub_src = ALUB_RF ; alu_op = 2'b01 ;
            end 
            OP_JAL: begin
                jp = JP_ADDI ; imme_src = IMM_J ; rf_wen = 1'b1 ; rf_rd_src = RD_PC ; 
                alub_src = alub_src_t'(1'bx) ; alua_src = alua_src_t'(2'bxx) ; alu_op = 2'bxx ;
            end 
            OP_LUI: begin
                imme_src = IMM_U ; rf_wen = 1'b1 ; alub_src = ALUB_IMME ; alua_src = ALUA_ZERO ;  alu_op = 2'b00 ;      
            end
            OP_AUIPC: begin
                imme_src = IMM_U ; rf_wen = 1'b1 ; alub_src = ALUB_IMME ; alua_src = ALUA_PC ;  alu_op = 2'b00 ;
            end
            default  : begin
                jp = JP_ADD4 ; branch = 1'b0 ; imme_src = IMM_I ; rf_wen = 1'b0 ; dm_wen = 1'b0 ; 
                rf_rd_src = RD_ALU ; alub_src = ALUB_RF ; alua_src = ALUA_RF ; alu_op = 2'b10 ; 
            end
        endcase
    end
    
    // alu_decoder
  
    assign alu_ctrl[2:0]    = alu_op[1] ? funct3 : 3'b000 ;
    assign alu_ctrl[3]      = (alu_op[1]&funct7&(opcode[5]|(funct3[1:0]==2'b01)))|alu_op[0] ; 
    
endmodule