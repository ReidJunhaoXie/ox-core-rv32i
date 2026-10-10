import core_pkg::*;

module imme_gen (
    input   logic   [31:7]  inst ,
    input   imme_src_t  imme_src ,
    output  logic   [31:0]  imme_ext 
);

    logic [31:0]    imme_ext_i ;
    logic [31:0]    imme_ext_s ;
    logic [31:0]    imme_ext_b ;
    logic [31:0]    imme_ext_u ;
    logic [31:0]    imme_ext_j ;


    assign imme_ext_i = { {20{inst[31]}},inst[31:20] } ;
    assign imme_ext_s = { {20{inst[31]}},inst[31:25],inst[11:7] } ;
    assign imme_ext_b = { {19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0 } ;
    assign imme_ext_u = { inst[31:12],12'b0 } ;
    assign imme_ext_j = { {11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0 } ;

    always_comb begin : immegen_mux
        imme_ext = imme_ext_i ;
        case (imme_src)
            IMM_I : imme_ext = imme_ext_i ;  //3'b000
            IMM_S : imme_ext = imme_ext_s ;  //3'b001
            IMM_B : imme_ext = imme_ext_b ;  //3'b011
            IMM_U : imme_ext = imme_ext_u ;  //3'b100
            IMM_J : imme_ext = imme_ext_j ;  //3'b101
            default: imme_ext = imme_ext_i ;
        endcase
    end

endmodule