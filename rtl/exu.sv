
module exu (
    input logic [31:0]  rf_rdata1 ,
    input logic [31:0]  rf_rdata2 ,
    input logic [31:0]  imme_ext ,

    input logic [2:0]   funct3 ,
    
    input logic [3:0]   alu_ctrl ,
    input logic [1:0]   jp ,
    input logic         branch ,
    input logic         alub_src ,


    input logic [31:0]  pc_in ,
    input logic [31:0]  pc_add4_in ,
    input logic [4:0]   rf_waddr ,

    output logic        flag ,
    output logic [31:0] alu_out ,

    output logic [1:0]  pc_src ,

    output logic [31:0] pc_adder_out,
    output logic [31:0] rf_rdata2_o ,
    output logic [31:0] pc_add4_o ,
    output logic [4:0]  rf_waddr_o 


);
    logic   [31:0]      rf_rdata2_imme ;

    assign rf_rdata2_imme =  alub_src?  imme_ext : rf_rdata2 ;
    alu u_alu(.rf_rdata1(rf_rdata1),.rf_rdata2_imme(rf_rdata2_imme),
              .alu_ctrl(alu_ctrl),.funct3(funct3),
              .flag(flag),.alu_out(alu_out)) ;
    assign pc_src = {jp[1],(branch&flag)|jp[0]} ; 

    assign pc_adder_out = imme_ext + pc_in ;

    assign rf_rdata2_o  = rf_rdata2 ;
    assign pc_add4_o    = pc_add4_in ;
    assign rf_waddr_o   = rf_waddr ;


endmodule