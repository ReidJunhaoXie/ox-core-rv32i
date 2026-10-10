import core_pkg::*;

module idu (
    input logic [31:0]    instruction, 
    input logic [31:0]    pc,
    input logic [31:0]    pc_add4,

    output id_ex_t  id_ex,         // pipeline signal

    output logic [4:0]    raddr1,         // with rf
    output logic [4:0]    raddr2
);
    logic [6:0]     opcode ;
    logic [14:12]   funct3 ;
    logic           funct7 ;
    logic [31:7]    imme ;

    assign opcode   = instruction[6:0] ;    
    assign funct3   = instruction[14:12] ;
    assign funct7   = instruction[30] ;
    assign imme     = instruction[31:7] ;
    logic [4:0]     waddr ;
    assign waddr    = instruction[11:7] ;   
    assign raddr1   = instruction[19:15] ; 
    assign raddr2   = instruction[24:20] ;

    assign id_ex.waddr      = waddr ;         
    assign id_ex.pc         = pc ;
    assign id_ex.pc_add4    = pc_add4 ;
    

    // decoder
    decoder u0 (.opcode(opcode),.funct3(funct3),
    .funct7(funct7),.jp(id_ex.jp),.branch(id_ex.branch),.imme_src(id_ex.imme_src),
    .rf_wen(id_ex.rf_wen),.dmem_wen(id_ex.dmem_wen),.rf_rd_src(id_ex.rf_rd_src),
    .alub_src(id_ex.alub_src),.alu_ctrl(id_ex.alu_ctrl)) ;

    // immegen
    imme_gen u1 (.inst(imme),.imme_src(id_ex.imme_src),.imme_ext(id_ex.imme_ext)) ;


endmodule