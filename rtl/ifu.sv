import core_pkg::*;

module ifu (
    input  logic clk,
    input  logic rst_n,
    input  logic [XLEN-1:0] pc_add_jmp,
    input  logic [XLEN-1:0] pc_add_jal,
    input  pc_src_t  pc_src,
    output logic [XLEN-1:0] pc,
    output logic [XLEN-1:0] pc_add4 
);
    logic [XLEN-1:0] pc_next ;
    assign pc_add4 = pc + 4 ;

    always_comb begin : pc_mux
        case (pc_src)
            PC_ADD4: pc_next = pc_add4 ;
            PC_JMP : pc_next = pc_add_jmp ;
            PC_JAL : pc_next =  pc_add_jal ;
            default: pc_next = pc_add4 ;
        endcase
    end
    always_ff @(posedge  clk or negedge rst_n) begin : pc_reg
        if (!rst_n) pc <= '0 ;
        else pc <= pc_next ;
    end
    
endmodule