// tb_ox_core.sv : first whole-core test: runs test.s and checks the registers and data memory
//   test.s avoids every hazard in software (the core has no hazard detection yet)
//   iverilog -g2012 -o sim/sim.out rtl/core_pkg.sv rtl/decoder.sv rtl/imme_gen.sv rtl/idu.sv rtl/ifu.sv \
//            rtl/shifter.sv rtl/alu_adder.sv rtl/alu.sv rtl/exu.sv rtl/lsu.sv rtl/wbu.sv rtl/reg_file.sv \
//            rtl/ox_core.sv tb/tb_ox_core.sv
//   vvp sim/sim.out                         (test.hex must be in the directory you run vvp from)
`timescale 1ns/1ps

module tb_ox_core;

    logic        clk = 0;
    logic        reset_n;
    logic [31:0] instr_im, dm_rdata_raw;
    logic [31:0] pc_im, dm_wdata;
    logic [31:0] dm_addr;                   // byte address, word aligned (bits [1:0] are 0)
    logic        dm_wen;
    logic [3:0]  dm_byteen;

    ox_core dut (.*);

    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Memories (both read asynchronously, as the core expects)
    // pc_im and dm_addr are byte addresses: bits [9:2] pick one of the 256 words
    // ------------------------------------------------------------------
    logic [31:0] imem [0:255];
    logic [31:0] dmem [0:255];

    assign instr_im     = imem[pc_im[9:2]];
    assign dm_rdata_raw = dmem[dm_addr[9:2]];

    // byte-enable write: only the enabled bytes of the word change
    function automatic logic [31:0] merge(input logic [31:0] old, wd, input logic [3:0] be);
        for (int i = 0; i < 4; i++)
            if (be[i]) old[8 * i +: 8] = wd[8 * i +: 8];
        return old;
    endfunction

    always @(posedge clk)
        if (dm_wen) dmem[dm_addr[9:2]] <= merge(dmem[dm_addr[9:2]], dm_wdata, dm_byteen);

    // ------------------------------------------------------------------
    // Checks
    // ------------------------------------------------------------------
    int errors = 0;

    task automatic check(input string name, input logic [31:0] got, exp);
        if (got !== exp) begin
            errors++;
            $display("[FAIL] %-12s = %h (expected %h)", name, got, exp);
        end
    endtask

    initial begin
        for (int i = 0; i < 256; i++) begin
            imem[i] = 32'h0000_0013;            // nop everywhere outside the program
            dmem[i] = 32'h0;
        end
        $readmemh("test_data/test.hex", imem);

        reset_n = 0;
        repeat (2) @(posedge clk);
        #1 reset_n = 1;
        repeat (150) @(posedge clk);            // the program ends in a loop at 0xb4 long before this
        #1;

        // label addresses come from: riscv64-unknown-elf-nm test.elf
        check("x1",  dut.u_rf.rf[1],  32'd100);
        check("x2",  dut.u_rf.rf[2],  32'hFFFF_FFF9);
        check("x3",  dut.u_rf.rf[3],  32'h1234_5678);
        check("x4",  dut.u_rf.rf[4],  32'd93);
        check("x5",  dut.u_rf.rf[5],  32'd107);
        check("x6",  dut.u_rf.rf[6],  32'h1234_5678);
        check("x7",  dut.u_rf.rf[7],  32'h0000_0012);
        check("x8",  dut.u_rf.rf[8],  32'h0000_0078);
        check("x9",  dut.u_rf.rf[9],  32'd1);
        check("x10 (skip)",  dut.u_rf.rf[10], 32'd0);           // bne must jump over these two
        check("x11 (skip)",  dut.u_rf.rf[11], 32'd0);
        check("x12 (link)",  dut.u_rf.rf[12], 32'h0000_0080);   // jal at skip = 0x7c
        check("x13 (ret)",   dut.u_rf.rf[13], 32'd1);           // set only after jalr returns
        check("x14",  dut.u_rf.rf[14], 32'd55);
        check("x15 (auipc)", dut.u_rf.rf[15], 32'h0000_00B0);   // done = 0xb0
        check("x16",  dut.u_rf.rf[16], 32'hFFFF_FFF9);
        check("x17",  dut.u_rf.rf[17], 32'h0000_FFF9);
        check("x31 (fail)",  dut.u_rf.rf[31], 32'd0);           // beq must not be taken
        check("DM[0x0]", dmem[0], 32'h1234_5678);
        check("DM[0x4]", dmem[1], 32'd93);
        check("DM[0x8]", dmem[2], 32'hFFFF_FFF9);
        // the program ends in "end: j end" at 0xb4; IF also fetches the two nops behind it (0xb8 / 0xbc)
        if (!(pc_im >= 32'hb4 && pc_im <= 32'hbc)) begin
            errors++;
            $display("[FAIL] pc_im        = %h (expected the end loop at 0xb4)", pc_im);
        end

        if (errors == 0) $display("PASS");
        else             $fatal(1, "FAIL: %0d errors", errors);
        $finish;
    end

endmodule