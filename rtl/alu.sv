module alu (
    input logic [31:0]  rf_rdata1,
    input logic [31:0]  rf_rdata2_imme,
    input logic [3:0]   alu_ctrl,
    input logic [2:0]   funct3,

    output logic        flag,
    output logic [31:0] alu_out
);
    logic [31:0]    adder_sum ;
    logic           lt ;
    logic           ltu ;

    logic [31:0]    shift_out ; 
    logic [31:0]    xor_out ;
    logic [31:0]    or_out ;
    logic [31:0]    and_out ;

    alu_adder u_adder(.rf_rdata1(rf_rdata1),.rf_rdata2_imme(rf_rdata2_imme),
    .alu_ctrl_3(alu_ctrl[3]),.alu_ctrl_1(alu_ctrl[1]),.funct3(funct3),
    .adder_sum_out(adder_sum),.lt(lt),.ltu(ltu),.flag(flag));

    shifter u_shifter(.shamt(rf_rdata2_imme[4:0]),.in(rf_rdata1),
    .sign(alu_ctrl[3]),.reverse(alu_ctrl[2]),
    .out(shift_out)) ;
    
    always_comb begin : logic_unit
        xor_out = rf_rdata1 ^ rf_rdata2_imme ;
        or_out  = rf_rdata1 | rf_rdata2_imme ;
        and_out = rf_rdata1 & rf_rdata2_imme ;
    end

    always_comb begin : out_mux
        alu_out = adder_sum ;
        case (alu_ctrl[2:0])
            3'b000 :    alu_out = adder_sum ;
            3'b001 :    alu_out = shift_out ;
            3'b010 :    alu_out = {31'b0,lt} ;
            3'b011 :    alu_out = {31'b0,ltu} ;
            3'b100 :    alu_out = xor_out ;
            3'b101 :    alu_out = shift_out ;
            3'b110 :    alu_out = or_out ;
            3'b111 :    alu_out = and_out ;
        endcase
    end
endmodule