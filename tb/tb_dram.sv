`timescale 1ns/1ps

module tb_dram ();
    localparam int A_WIDTH = 12 ;

    logic clk ;
    logic [31:0] addr ;
    logic we ;
    logic [3:0] byteen ;
    logic [31:0] wdata ;
    logic [31:0] rdata ;
    
    dummy_dram #(
        .A_WIDTH(A_WIDTH)
    ) dut (
        .clk(clk),
        .addr(addr),
        .we(we),
        .byteen(byteen),
        .rdata(rdata),
        .wdata(wdata)
    );

    // clk gen 
    initial begin
        clk = 0 ;
        forever #5 clk = ~clk ;
    end

    // Stimulus
    initial begin
        // initialization
        wdata = '0 ; addr = '0 ;
        we = 0 ; byteen = '1 ; // byteen = 1111
        // doesnt test byteen
        @(posedge clk) ;
        @(posedge clk) ; // stop 2 posedge to be stable

        // Sync Wrtie Async Read =====
        $display("[Test 1] Sync Write Async Wrtie") ;
        // Sync Write Async Read word1
        @(negedge clk) ; // preparing data
        // write w1 data
        wdata = 32'hDEADBEEF ; addr = '0 ;
        we = 1 ; byteen = '1 ; // byteen = 1111      
        @(posedge clk) ; // wrtie
        @(negedge clk) ; // Read
        we = 0 ; 

        # 1 ;
        if(rdata!=32'hDEADBEEF) $error("Word1 Write Fail,Write %h,Read %h",wdata,rdata);
        else $display("[Word1]Sucess");
        
        // Sync Write Async Read word2
        @(negedge clk) ; // preparing data
        // write w2 data
        wdata = 32'hD1ADB555 ; addr = 32'd4 ; // only word read
        we = 1 ; byteen = '1 ; // byteen = 1111      
        @(posedge clk) ; // wrtie
        @(negedge clk) ; // Read
        we = 0 ; addr = 32'd4 ;

        # 1 ;
        if(rdata!=32'hD1ADB555) $error("Word12 Write Fail,Write %h,Read %h",wdata,rdata);
        else $display("[Word2]Sucess");

        $finish;
    end
    
endmodule