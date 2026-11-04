module shifter (
    input   logic [4:0] shamt , // imme/rdata2
    input   logic sign ,        // alu_ctrl[3]
    input   logic reverse ,     // alu_ctrl[2]
    input   logic [31:0] in ,   
    output  logic [31:0] out
);
    logic [31:0] rvs_in ; // reverse in
    logic [31:0] in_mux ; // post-mux

    logic shift_in_bit ;  

    logic [31:0] shift_s1 ;
    logic [31:0] shift_s2 ;
    logic [31:0] shift_s3 ;
    logic [31:0] shift_s4 ;
    logic [31:0] shift_s5 ;

    always_comb begin : bit_reverse_1
        for(int i=0;i<32;i++) rvs_in[i] = in[31-i] ; // reverse input

        // left/right mux
        if (reverse) in_mux = rvs_in ;
        else in_mux = in ;
    end

    assign shift_in_bit = sign ? in[31] : 1'b0 ;

    assign shift_s1 = shamt[0]? {  in_mux[30:0],shift_in_bit} : in_mux ;
    assign shift_s2 = shamt[1]? {shift_s1[29:0],{ 2 {shift_in_bit} } } : shift_s1 ;
    assign shift_s3 = shamt[2]? {shift_s2[27:0],{ 4 {shift_in_bit} } } : shift_s2 ;
    assign shift_s4 = shamt[3]? {shift_s3[23:0],{ 8 {shift_in_bit} } } : shift_s3 ;
    assign shift_s5 = shamt[4]? {shift_s4[15:0],{ 16{shift_in_bit} } } : shift_s4 ;


    logic [31:0] rvs_out ;
    always_comb begin : bit_reverse_2
        for(int i=0;i<32;i++) rvs_out[i] = shift_s5[31-i] ; // reverse output

        if (reverse) out =  rvs_out ;
        else out = shift_s5 ;
    end

endmodule