// tb_wbu.sv : wbu testbench (every rf_rd_src value, directed + random data)
//   iverilog -g2012 -o sim/sim.out rtl/wbu.sv tb/tb_wbu.sv
//   vvp sim/sim.out
`timescale 1ns/1ps

module tb_wbu;

    // signals with the same names as the wbu ports
    logic [1:0]  rf_rd_src;
    logic [31:0] dm_rdata, alu_out, pc_add4;
    logic [31:0] rf_wdata;

    wbu dut (.*);       // signal names match the port names, so .* connects them automatically

    int errors = 0;
    int n_test = 0;

    // ------------------------------------------------------------------
    // Reference model: the value written back to rd for each rf_rd_src
    // ------------------------------------------------------------------
    function automatic logic [31:0] ref_wdata(input logic [1:0]  src,
                                              input logic [31:0] dm, alu, pc4);
        case (src)
            2'b00  : return dm;      // load       : data read from memory
            2'b01  : return alu;     // R / I-type : ALU result
            2'b10  : return pc4;     // JAL / JALR : return address pc + 4
            default: return pc4;     // 11 is not used by the decoder; the RTL's default gives pc_add4
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Test task
    // ------------------------------------------------------------------

    // one write-back: apply the select and the three inputs, check rf_wdata
    task automatic wb_test(input string       name,
                           input logic [1:0]  src,
                           input logic [31:0] dm, alu, pc4);
        logic [31:0] expected;
        expected  = ref_wdata(src, dm, alu, pc4);   // expected value from the reference model

        rf_rd_src = src;
        dm_rdata  = dm;
        alu_out   = alu;
        pc_add4   = pc4;
        #1;
        n_test++;
        if (rf_wdata !== expected) begin
            errors++;
            if (errors <= 10)
                $display("[FAIL] %s : rf_rd_src = %b, dm_rdata = %h, alu_out = %h, pc_add4 = %h -> rf_wdata = %h (expected %h)",
                         name, src, dm, alu, pc4, rf_wdata, expected);
        end
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    logic [31:0] rand_dm, rand_alu, rand_pc4;     // random values for test group 3

    initial begin
        // 1. each source once; the three inputs hold different, easy-to-recognise values
        //    (D... = memory, A... = ALU, 0000_1004 = pc + 4), so a failure shows at a glance which input was picked
        //       name                 src    dm_rdata       alu_out        pc_add4
        wb_test("load   -> dm_rdata", 2'b00, 32'hDA7A_1234, 32'hA1B2_C3D4, 32'h0000_1004);
        wb_test("ALU    -> alu_out",  2'b01, 32'hDA7A_1234, 32'hA1B2_C3D4, 32'h0000_1004);
        wb_test("JAL(R) -> pc_add4",  2'b10, 32'hDA7A_1234, 32'hA1B2_C3D4, 32'h0000_1004);
        wb_test("unused 11",          2'b11, 32'hDA7A_1234, 32'hA1B2_C3D4, 32'h0000_1004);

        // 2. the selected input is the exact opposite of the other two, so every output bit
        //    must be 1 in one test and 0 in the other, and must come from the selected input
        //       name                 src    dm_rdata       alu_out        pc_add4
        wb_test("load   ones",        2'b00, 32'hFFFF_FFFF, 32'h0000_0000, 32'h0000_0000);
        wb_test("load   zeros",       2'b00, 32'h0000_0000, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        wb_test("ALU    ones",        2'b01, 32'h0000_0000, 32'hFFFF_FFFF, 32'h0000_0000);
        wb_test("ALU    zeros",       2'b01, 32'hFFFF_FFFF, 32'h0000_0000, 32'hFFFF_FFFF);
        wb_test("JAL(R) ones",        2'b10, 32'h0000_0000, 32'h0000_0000, 32'hFFFF_FFFF);
        wb_test("JAL(R) zeros",       2'b10, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'h0000_0000);
        wb_test("unused ones",        2'b11, 32'h0000_0000, 32'h0000_0000, 32'hFFFF_FFFF);
        wb_test("unused zeros",       2'b11, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'h0000_0000);

        // 3. random values on all three inputs, 100 times for every source
        for (int s = 0; s < 4; s++)
            repeat (100) begin
                // draw again if two inputs are equal: picking the wrong one would then look correct
                do begin
                    rand_dm  = $urandom;
                    rand_alu = $urandom;
                    rand_pc4 = $urandom;
                end while (rand_dm == rand_alu || rand_dm == rand_pc4 || rand_alu == rand_pc4);
                wb_test("random", s[1:0], rand_dm, rand_alu, rand_pc4);
            end

        $display("%0d tests, %0d errors", n_test, errors);
        if (errors == 0) $display("PASS");
        else             $fatal(1, "FAIL");
        $finish;
    end

endmodule