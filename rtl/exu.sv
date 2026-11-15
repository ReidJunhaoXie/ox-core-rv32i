module exu 
import core_pkg::*;
(
    input logic [31:0]  rf_rdata1 ,
    input logic [31:0]  rf_rdata2 ,
    input logic [31:0]  imme_ext ,
    input logic [31:0]  pc_in ,

    // control signal
    input logic [2:0]   funct3 ,
    input logic [3:0]   alu_ctrl ,
    input jp_t          jp ,
    input logic         branch ,
    input alub_src_t    alub_src ,
    input alua_src_t    alua_src ,
    // input logic [4:0]   rf_waddr ,

    output pc_src_t     pc_src ,        // to IF
    output logic [31:0] alu_out ,       // to IF and MEM
    output logic [31:0] pc_adder_out,
    output logic [31:0] pc_add4
    // output logic [31:0] rf_rdata2_o ,
    // output logic [4:0]  rf_waddr_o 
);
    // input of alu
    logic   [31:0]      alu_b ;
    logic   [31:0]      alu_a ; 
    assign alu_b =  (alub_src==ALUB_IMME)? imme_ext : rf_rdata2 ;
    assign alu_a =  (alua_src==ALUA_RF)? rf_rdata1 : (alua_src==ALUA_ZERO)? '0 : pc_in ;

    logic   flag ;
    alu u_alu(.rf_rdata1(alu_a),.rf_rdata2_imme(alu_b),
              .alu_ctrl(alu_ctrl),.funct3(funct3),
              .flag(flag),.alu_out(alu_out)) ;
    assign pc_src = pc_src_t'({jp[1],(branch&flag)|jp[0]}) ; 

    assign pc_adder_out = imme_ext + pc_in ;
    assign pc_add4      = 32'd4 + pc_in ;


endmodule