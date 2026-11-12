
module ifu 
    import core_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] pc_add_jmp,
    input  logic [31:0] pc_add_jalr,
    input  pc_src_t     pc_src,
    output logic [31:0] pc
);
    logic [31:0]    pc_next ;
    logic [31:0]    pc_add4 ;
    assign pc_add4 = pc + 4 ;

    always_comb begin : pc_mux
        case (pc_src)
            PC_ADD4:    pc_next = pc_add4 ;
            PC_ADDI:    pc_next = pc_add_jmp ;
            PC_ALU:     pc_next = {pc_add_jalr[31:1],1'b0} ;
            default:    pc_next = pc_add4 ;
        endcase
    end
    always_ff @(posedge clk or negedge rst_n) begin : pc_reg
        if (!rst_n) pc <= '0 ;
        else pc <= pc_next ;
    end
    
endmodule
