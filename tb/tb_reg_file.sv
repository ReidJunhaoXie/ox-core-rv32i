`timescale 1ns/1ps

module tb_reg_file ();

    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 5;
    
    logic clk;
    logic [ADDR_WIDTH-1:0] raddr1,raddr2;
    logic [DATA_WIDTH-1:0] rdata1,rdata2;
    logic we;
    logic [ADDR_WIDTH-1:0] waddr;
    logic [DATA_WIDTH-1:0] wdata;

    reg_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    dut(
        .clk(clk),
        .raddr1(raddr1), .rdata1(rdata1),
        .raddr2(raddr2), .rdata2(rdata2),
        .we(we),
        .waddr(waddr),
        .wdata(wdata)
    );
    // clk gen ========================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("sim/rf_wave.vcd");
        $dumpvars(0,tb_reg_file);
    end

    // Stimulus =======================
    initial begin
        // initialize
        we=0 ; waddr='0 ; wdata = '0;
        raddr1='0 ; raddr2='0 ;

        @(posedge clk);
        @(posedge clk);

        // r1 test================================================
        // x0 iso test===========
        $display("\n[RS1][test 1] x0 isolated test");
        @(negedge clk);          // negedge : preparing data
        // Sync write x0 32'F and Async read x0
        we=1;
        waddr=5'd0;
        wdata=32'hFFFF_FFFF;
        raddr1=5'd0;            // not neccesary, 0 is default
        @(posedge clk);         // write x0
        @(negedge clk);         // expectation : read x0=>0 / write x0 fail
        we=0;
        waddr=5'd0;
        wdata=32'hFFFF_FFFF;    // dont care
        raddr1=5'd0;
        #1;
        if(rdata1!=32'h0) $error("[RS1][Test 1] Fail: x0 write got %h",rdata1);

        // write through iso test===========
        $display("\n[RS1][test 2]write-through isolated test");
        // nededge write through
        @(negedge clk);
        we=1;
        waddr=5'd1;
        wdata=32'hFFFF_FFF0;
        raddr1=5'd1;
        #1;
        if(rdata1!=32'hFFFF_FFF0) $error("Test 2 Fail: RS1.nededge Write-Through failed");
        // posedge write through
        @(posedge clk);
        we=1;
        waddr=5'd2;
        wdata=32'hFFFF_FF0F;
        raddr1=5'd2;
        #1;
        if(rdata1!=32'hFFFF_FF0F) $error("Test 2 Fail: RS1.posedge Write-Through failed");

        // x0 & write through test==============
        $display("\n[RS1][TEST 3] x0 & write-through test");
        @(negedge clk);
        we=1;
        waddr=5'd0;
        wdata=32'hFFFF_F0FF;
        raddr1=5'd0;
        #1;
        if (rdata1 !== '0) $error("Test 3 Fail: RS1 - x0=0 > write-through failed");

        // Normal R/W test================================
        $display("\n[RS1][TEST 4] Normal R/W Test");
        // cycle 1 : IF(Read) -> ID -> EX -> MEM -> WB(Write)
        // cycle 2 : IF -> ID(Read) -> EX -> MEM -> WB
        @(negedge clk);
        we=1;
        waddr=5'd20;
        wdata=32'hAAAA_BBBB;
        raddr1=5'd0; // read default

        @(posedge clk);
        @(negedge clk);
        we=0;
        raddr1=5'd20; // read 20
        
        #1;
        if(rdata1!=32'hAAAA_BBBB) $error("Test 4 Fail (RS1):Normal R/W failed - Got %h", rdata1);


        // r2 test================================================
        // x0 iso test===========
        $display("\n[RS2][test 1] x0 isolated test");
        @(negedge clk);          // negedge : preparing data
        // Sync write x0 32'F and Async read x0
        we=1;
        waddr=5'd0;
        wdata=32'hFFFF_FFFF;
        raddr2=5'd0;            // not neccesary, 0 is default
        @(posedge clk);         // write x0
        @(negedge clk);         // expectation : read x0=>0 / write x0 fail
        we=0;
        waddr=5'd0;
        wdata=32'hFFFF_FFFF;    // dont care
        raddr2=5'd0;
        #1;
        if(rdata2!=32'h0) $error("[RS2][Test 1] Fail: x0 write got %h",rdata2);

        // write through iso test===========
        $display("\n[RS2][test 2]write-through isolated test");
        // nededge write through
        @(negedge clk);
        we=1;
        waddr=5'd1;
        wdata=32'hFFFF_FFF0;
        raddr2=5'd1;
        #1;
        if(rdata2!=32'hFFFF_FFF0) $error("Test 2 Fail: RS2.nededge Write-Through failed");
        // posedge write through
        @(posedge clk);
        we=1;
        waddr=5'd2;
        wdata=32'hFFFF_FF0F;
        raddr2=5'd2;
        #1;
        if(rdata2!=32'hFFFF_FF0F) $error("Test 2 Fail: RS2.posedge Write-Through failed");

        // x0 & write through test==============
        $display("\n[RS2][TEST 3] x0 & write-through test");
        @(negedge clk);
        we=1;
        waddr=5'd0;
        wdata=32'hFFFF_F0FF;
        raddr2=5'd0;
        #1;
        if (rdata2 !== '0) $error("Test 3 Fail: RS2 - x0=0 > write-through failed");

        // Normal R/W test================================
        $display("\n[RS2][TEST 4] Normal R/W Test");
        // cycle 1 : IF(Read) -> ID -> EX -> MEM -> WB(Write)
        // cycle 2 : IF -> ID(Read) -> EX -> MEM -> WB
        @(negedge clk);
        we=1;
        waddr=5'd20;
        wdata=32'hAAAA_BBBB;
        raddr2=5'd0; // read default

        @(posedge clk);
        @(negedge clk);
        we=0;
        raddr2=5'd20; // read 20
        
        #1;
        if(rdata2!=32'hAAAA_BBBB) $error("Test 4 Fail (RS2):Normal R/W failed - Got %h", rdata2); 

        $finish;

    end


endmodule