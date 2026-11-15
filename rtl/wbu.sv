module wbu 
import core_pkg::*;
(
    input   rf_rd_src_t     rf_rd_src ,
    input   logic   [31:0]  dm_rdata ,
    input   logic   [31:0]  alu_out ,
    input   logic   [31:0]  pc_add4 ,
    output  logic   [31:0]  rf_wdata
);
    always_comb begin : rf_w_mux
        case (rf_rd_src)
            RD_DM:      rf_wdata = dm_rdata ;
            RD_ALU:     rf_wdata = alu_out ;
            default:    rf_wdata = pc_add4 ;
        endcase
    end
endmodule