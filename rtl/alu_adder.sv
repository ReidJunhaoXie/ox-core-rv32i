module alu_adder (
    input logic [31:0]  rf_rdata1,
    input logic [31:0]  rf_rdata2_imme,
    input logic         alu_ctrl_3,
    input logic         alu_ctrl_1,
    input logic [2:0]   funct3,

    output logic [31:0] adder_sum_out,
    output logic        lt,
    output logic        ltu,
    output logic        flag
);
    logic           sub_en ;
    assign sub_en = alu_ctrl_1 | alu_ctrl_3 ;
    logic [31:0]    adder_a ;
    logic [31:0]    adder_b ;
    assign adder_a = rf_rdata1 ;
    assign adder_b = rf_rdata2_imme ^ {32{sub_en}} ;    // bit inverse

    logic   zero ;
    logic   cond ;
    logic [31:0]    sum ;
    logic           cout ;
    always_comb begin : flag_mux
        cond = zero ;
        case (funct3[2:1])
            2'b00: cond = zero ;
            2'b10: cond = lt ;
            2'b11: cond = ltu ; 
        endcase
        flag = cond ^ funct3[0] ;
    end

    assign {cout,sum} = adder_a + adder_b + sub_en ; // add 1 after inverse
    assign ltu  = ~cout ;
    assign lt   = (adder_a[31]!=adder_b[31])? sum[31] : adder_a[31] ;
    assign zero = (sum==32'b0) ;

    assign adder_sum_out = sum ;

endmodule