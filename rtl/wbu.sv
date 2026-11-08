module wbu (
    input   logic   [1:0]   rf_rd_src ,
    input   logic   [31:0]  dm_rdata ,
    input   logic   [31:0]  alu_out ,
    input   logic   [31:0]  pc_add4 ,
    output  logic   [31:0]  rf_wdata
);
    always_comb begin : rf_w_mux
        case (rf_rd_src)
            2'b00: rf_wdata = dm_rdata ;
            2'b01: rf_wdata = alu_out ;
            default: rf_wdata = pc_add4 ;
        endcase
    end
endmodule