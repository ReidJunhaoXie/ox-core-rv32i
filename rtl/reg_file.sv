// load package
import core_pkg::*;

module reg_file #(
    parameter int DATA_WIDTH = core_pkg::XLEN,
    parameter int ADDR_WIDTH = core_pkg::REG_ADDR_WIDTH
)
(
    input logic clk,
//Async Read port1
    input logic [ADDR_WIDTH-1:0] raddr1,
    output logic [DATA_WIDTH-1:0] rdata1,
//Async Read port2
    input logic [ADDR_WIDTH-1:0] raddr2,
    output logic [DATA_WIDTH-1:0] rdata2,
//Sync Wrtie port
    input logic we,
    input logic [ADDR_WIDTH-1:0] waddr,
    input logic [DATA_WIDTH-1:0] wdata
);
logic [DATA_WIDTH-1:0] rf [1:31]; // without x0

// Sync Write
always_ff @( posedge clk ) begin : Sync_Write
    if(we && waddr != 0) begin
        rf[waddr] <= wdata ;
    end
end

// Async Read
always_comb begin : Async_Read
    if(raddr1=='0) rdata1 = 0;
    else if(we&&(raddr1==waddr)) rdata1 = wdata;
    else rdata1 = rf[raddr1];

    if(raddr2=='0) rdata2 = 0;
    else if(we&&(raddr2==waddr)) rdata2 = wdata;
    else rdata2 = rf[raddr2];
end

endmodule