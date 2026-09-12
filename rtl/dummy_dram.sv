`timescale 1ns/1ps
import core_pkg::*;

module dummy_dram #(
    parameter int A_WIDTH = core_pkg::DRAM_ADDR_WIDTH
) (
    input logic clk,
    input logic [31:0] addr,
    input logic we, // write enable
    input logic [3:0] byteen, // byte enable
    input logic [31:0] wdata, // write data
    output logic [31:0] rdata  // read data
);
    logic [31:0] ram [0:(1<<(A_WIDTH-2))-1] // 12-2 << 1 => 1024-1 => 1023

    // simulation initialize
    initial begin
        for (int i=0; i<(1<<(A_WIDTH-2)); i++) begin
            ram[i] = 32'b0 ;
        end
    end
    // Async read
    // ==========
    assign rdata = ram[addr[(A_WIDTH-1):2]] ;

    // Sync wirte
    // ==========
    always_ff @( posedge clk ) begin
        if (we) begin
            if(byteen[0]) ram[addr[(A_WIDTH-1):2]][7:0] <= wdata[7:0] ;
            if(byteen[1]) ram[addr[(A_WIDTH-1):2]][15:8] <= wdata[15:8] ;
            if(byteen[2]) ram[addr[(A_WIDTH-1):2]][23:16] <= wdata[23:16] ;
            if(byteen[3]) ram[addr[(A_WIDTH-1):2]][31:24] <= wdata[31:24] ;
        end
    end

endmodule