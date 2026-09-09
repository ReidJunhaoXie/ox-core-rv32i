`timescale 1ns/1ps

module tb_iram();
    localparam int A_WIDTH = 12;

    logic [31:0] pc ;
    logic [31:0] inst ;

    dummy_iram #(
        .A_WIDTH(A_WIDTH)
    )
    dut(
        .pc(pc),
        .inst(inst)
    );

    initial begin
        $dumpfile("sim/iram_wave.vcd");
        $dumpvars(0,tb_iram);
    end

    /* firmware
    00500093
    00A00113
    002081B3
    00302023
    00000063
    */

    // Stimulus =============================
    initial begin
        #5 ;      // time of loading firmware

        //[TEST 1] PC incremental ==================
        $display("[TEST 1] PC incremental test (PC = 0, 4, 8, 12)");
        pc = 32'd0 ;
        #1 ;
        if (inst !== 32'h00500093) $error("Fail. PC=0 read error: %h",inst);
        else $display("\n Sucess");
        
        pc = 32'd4 ;
        #1 ;
        if (inst !== 32'h00A00113) $error("Fail. PC=4 read error: %h",inst);

        pc = 32'd8 ;
        #1 ;
        if (inst !== 32'h002081B3) $error("Fail. PC=8 read error: %h",inst);
        else $display("\n Sucess");

        pc = 32'd12 ;
        #1 ;
        if (inst !== 32'h00302023) $error("Fail. PC=12 read error: %h",inst);  
        else $display("\n Sucess");  
        
        pc = 32'd16 ;
        #1 ;
        if (inst !== 32'h00000063) $error("Fail. PC=16 read error: %h",inst); 
        else $display("\n Sucess");      

        //[TEST 2] illegal PC ===================
        $display("\n[TEST 2] PC illegal test (PC = 1, 3, 5, 7)");
        $display("\nPC = 1 => 0 / PC = 3 => 0 / PC = 5 => 4 / PC = 7 => 4");

        pc = 32'd1 ;
        #1 ;
        if (inst !== 32'h00500093) $error("Fail. PC=1(0) read error: %h",inst);
        else $display("\n Sucess");

        pc = 32'd3 ;
        #1 ;
        if (inst !== 32'h00500093) $error("Fail. PC=3(0) read error: %h",inst);
        else $display("\n Sucess");

        pc = 32'd5 ;
        #1 ;
        if (inst !== 32'h00A00113) $error("Fail. PC=5(4) read error: %h",inst);
        else $display("\n Sucess");

        pc = 32'd7 ;
        #1 ;
        if (inst !== 32'h00A00113) $error("Fail. PC=7(4) read error: %h",inst);
        else $display("\n Sucess");

        $finish ;
        
    end

endmodule