// tb_lsu.sv : lsu testbench (exhaustive funct3 / addr + reference model)
//   iverilog -g2012 -o sim/sim.out rtl/lsu.sv tb/tb_lsu.sv
//   vvp sim/sim.out
`timescale 1ns/1ps

module tb_lsu;

    // signals with the same names as the lsu ports
    logic [1:0]  addr;
    logic [31:0] rf_rdata2, dm_rdata;
    logic [2:0]  funct3;
    logic        dm_wen;
    logic [31:0] dm_wdata_o, dm_rdata_o;
    logic [3:0]  byteen;
    logic        dm_wen_o;

    lsu dut (.*);

    // stores and loads are counted separately, so failures of one kind cannot hide the other
    int store_errors = 0, n_store = 0;
    int load_errors  = 0, n_load  = 0;
    localparam int MAX_PRINT = 10;            // print at most this many failures of each kind

    // ------------------------------------------------------------------
    // Reference model (written from the spec, not from the RTL)
    // ------------------------------------------------------------------

    // expected byteen: sb writes 1 lane, sh 2 lanes (addr[0] ignored), sw 4 lanes (addr ignored)
    function automatic logic [3:0] ref_byteen(input logic wen, input logic [1:0] f3, input logic [1:0] a);
        if (!wen) return 4'b0000;
        case (f3)
            2'b00:   case (a)
                         2'd0: return 4'b0001;
                         2'd1: return 4'b0010;
                         2'd2: return 4'b0100;
                         default: return 4'b1000;
                     endcase
            2'b01:   return a[1] ? 4'b1100 : 4'b0011;
            2'b10:   return 4'b1111;
            default: return 4'b0000;          // not an RV32I store
        endcase
    endfunction

    // memory word after the store, starting from mem
    function automatic logic [31:0] ref_store(input logic [1:0] f3, input logic [1:0] a,
                                              input logic [31:0] data, input logic [31:0] mem);
        case (f3)
            2'b00:   mem[8 * a +: 8]     = data[7:0];
            2'b01:   mem[16 * a[1] +: 16] = data[15:0];
            2'b10:   mem                 = data;
            default: ;                        // not a store: memory unchanged
        endcase
        return mem;
    endfunction

    // what a memory with byte enables does with (byteen, wdata)
    function automatic logic [31:0] apply_write(input logic [31:0] mem, input logic [3:0] be, input logic [31:0] wd);
        for (int i = 0; i < 4; i++)
            if (be[i]) mem[8 * i +: 8] = wd[8 * i +: 8];
        return mem;
    endfunction

    // expected load result: shift the wanted part down, then sign- or zero-extend
    function automatic logic [31:0] ref_load(input logic [2:0] f3, input logic [1:0] a, input logic [31:0] w);
        logic        [7:0]  b;
        logic        [15:0] h;
        logic signed [7:0]  sb;
        logic signed [15:0] sh;
        logic signed [31:0] r;
        b  = w >> (8 * a);                    // byte at lane a
        h  = w >> (16 * a[1]);                // half at lane a[1]
        sb = b;
        sh = h;
        case (f3)
            3'b000:  r = sb;                  // lb : signed, so the assignment sign-extends
            3'b001:  r = sh;                  // lh
            3'b100:  r = b;                   // lbu: unsigned, so the assignment zero-extends
            3'b101:  r = h;                   // lhu
            default: r = w;                   // lw
        endcase
        return r;
    endfunction

    // ------------------------------------------------------------------
    // Test tasks
    // ------------------------------------------------------------------

    // one store: check byteen, and check the memory word that results from (byteen, dm_wdata_o)
    task automatic store_test(input logic wen, input logic [1:0] f3, input logic [1:0] a,
                              input logic [31:0] data, input logic [31:0] mem);
        logic [3:0]  exp_be;
        logic [31:0] exp_mem, got_mem;
        exp_be  = ref_byteen(wen, f3, a);
        exp_mem = wen ? ref_store(f3, a, data, mem) : mem;

        dm_wen    = wen;
        funct3    = {1'b0, f3};
        addr      = a;
        rf_rdata2 = data;
        dm_rdata  = $urandom;                 // not used by a store
        #1;
        n_store++;
        got_mem = apply_write(mem, byteen, dm_wdata_o);
        if (byteen !== exp_be || got_mem !== exp_mem || dm_wen_o !== wen) begin
            store_errors++;
            if (store_errors <= MAX_PRINT)
                $display("[FAIL] store wen=%b f3=%b addr=%0d data=%h : byteen=%b (exp %b), mem=%h (exp %h)",
                         wen, f3, a, data, byteen, exp_be, got_mem, exp_mem);
        end
    endtask

    // one load: check dm_rdata_o
    task automatic load_test(input logic [2:0] f3, input logic [1:0] a, input logic [31:0] word);
        logic [31:0] exp;
        exp = ref_load(f3, a, word);

        dm_wen    = 1'b0;
        funct3    = f3;
        addr      = a;
        dm_rdata  = word;
        rf_rdata2 = $urandom;                 // not used by a load
        #1;
        n_load++;
        if (dm_rdata_o !== exp || byteen !== 4'b0000) begin
            load_errors++;
            if (load_errors <= MAX_PRINT)
                $display("[FAIL] load f3=%b addr=%0d word=%h : dm_rdata_o=%h (exp %h), byteen=%b",
                         f3, a, word, dm_rdata_o, exp, byteen);
        end
    endtask

    // ------------------------------------------------------------------
    // Tests: every funct3 x every addr, with directed and random data
    // ------------------------------------------------------------------
    logic [31:0] patterns [8];
    logic [2:0]  ld_f3    [5];

    initial begin
        // each byte / half has its sign bit set in some patterns and clear in others
        patterns[0] = 32'h0000_0000;  patterns[1] = 32'hFFFF_FFFF;
        patterns[2] = 32'h8080_8080;  patterns[3] = 32'h7F7F_7F7F;
        patterns[4] = 32'h8000_8000;  patterns[5] = 32'h7FFF_7FFF;
        patterns[6] = 32'h1234_5678;  patterns[7] = 32'hF00D_BEEF;
        ld_f3[0] = 3'b000;  ld_f3[1] = 3'b001;  ld_f3[2] = 3'b010;   // lb  lh  lw
        ld_f3[3] = 3'b100;  ld_f3[4] = 3'b101;                       // lbu lhu

        // stores: dm_wen x funct3[1:0] x addr, directed + random data
        for (int w = 0; w < 2; w++)
            for (int f = 0; f < 4; f++)
                for (int a = 0; a < 4; a++) begin
                    for (int p = 0; p < 8; p++)
                        store_test(w[0], f[1:0], a[1:0], patterns[p], ~patterns[p]);
                    repeat (50)
                        store_test(w[0], f[1:0], a[1:0], $urandom, $urandom);
                end

        // loads: every valid load funct3 x addr, directed + random data
        for (int f = 0; f < 5; f++)
            for (int a = 0; a < 4; a++) begin
                for (int p = 0; p < 8; p++)
                    load_test(ld_f3[f], a[1:0], patterns[p]);
                repeat (50)
                    load_test(ld_f3[f], a[1:0], $urandom);
            end

        $display("store: %0d tests, %0d errors", n_store, store_errors);
        $display("load : %0d tests, %0d errors", n_load,  load_errors);
        if (store_errors + load_errors == 0) $display("PASS");
        else                                 $fatal(1, "FAIL");
        $finish;
    end

endmodule