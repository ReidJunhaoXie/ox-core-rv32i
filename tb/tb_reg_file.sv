// tb_reg_file.sv : register file testbench (directed + random, reference model)
//   iverilog -g2012 -o sim/sim.out rtl/reg_file.sv tb/tb_reg_file.sv
//   vvp sim/sim.out
`timescale 1ns/1ps

module tb_reg_file;

    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 5;
    localparam int N_REG      = 1 << ADDR_WIDTH;        // 32 registers, x0 included

    logic                  clk;
    logic [ADDR_WIDTH-1:0] raddr1, raddr2, waddr;
    logic [DATA_WIDTH-1:0] rdata1, rdata2, wdata;
    logic                  we;

    reg_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .raddr1(raddr1), .rdata1(rdata1),
        .raddr2(raddr2), .rdata2(rdata2),
        .we(we),
        .waddr(waddr),
        .wdata(wdata)
    );

    // clock ==============================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("sim/rf_wave.vcd");
        $dumpvars(0, tb_reg_file);
    end

    int errors  = 0;
    int n_check = 0;

    // ------------------------------------------------------------------
    // Reference model: what every register should hold (x0 is always 0)
    // ------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] model [N_REG];

    // expected read value in a cycle where (w, wa, wd) is being written
    function automatic logic [DATA_WIDTH-1:0] ref_read(input logic [ADDR_WIDTH-1:0] ra,
                                                        input logic                  w,
                                                        input logic [ADDR_WIDTH-1:0] wa,
                                                        input logic [DATA_WIDTH-1:0] wd);
        if (ra == 0)       return '0;       // x0 always reads 0, even in a cycle that writes x0
        if (w && ra == wa) return wd;       // write-through: the value being written this cycle
        return model[ra];                   // otherwise the stored value
    endfunction

    // ------------------------------------------------------------------
    // One clock cycle:
    //   drive the inputs at negedge (half a cycle away from the write edge, so the flip-flops
    //   never race with the testbench), check both read ports, then let the posedge write
    // ------------------------------------------------------------------
    task automatic cycle(input string                 name,
                         input logic                  w,
                         input logic [ADDR_WIDTH-1:0] wa,
                         input logic [DATA_WIDTH-1:0] wd,
                         input logic [ADDR_WIDTH-1:0] ra1, ra2);
        logic [DATA_WIDTH-1:0] exp1, exp2;
        @(negedge clk);
        we     = w;
        waddr  = wa;
        wdata  = wd;
        raddr1 = ra1;
        raddr2 = ra2;
        exp1   = ref_read(ra1, w, wa, wd);
        exp2   = ref_read(ra2, w, wa, wd);
        #1;
        n_check++;
        if (rdata1 !== exp1 || rdata2 !== exp2) begin          // !== also catches x
            errors++;
            if (errors <= 10)
                $display("[FAIL] %s : we=%b waddr=x%0d wdata=%h | rs1=x%0d -> %h (exp %h) | rs2=x%0d -> %h (exp %h)",
                         name, w, wa, wd, ra1, rdata1, exp1, ra2, rdata2, exp2);
        end
        @(posedge clk);                                        // the register file writes here
        if (w && wa != 0) model[wa] = wd;
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    logic                  r_we;                               // random values for test 6
    logic [ADDR_WIDTH-1:0] r_wa, r_ra1, r_ra2;
    logic [DATA_WIDTH-1:0] r_wd;

    initial begin
        for (int i = 0; i < N_REG; i++) model[i] = 'x;         // nothing has been written yet
        model[0] = '0;
        we = 0;  waddr = '0;  wdata = '0;  raddr1 = '0;  raddr2 = '0;

        // 1. give every register its own value, then read them all back on both ports at once.
        //    Port 2 reads in the opposite order, so the two ports always read different registers:
        //    this catches registers sharing storage (an address bit ignored) and swapped ports.
        for (int i = 1; i < N_REG; i++)
            cycle("fill", 1'b1, i, {4{8'(i)}} ^ 32'hA5C3_0F96, 0, 0);
        for (int i = 0; i < N_REG; i++)
            cycle("read all", 1'b0, 0, 0, i, N_REG - 1 - i);

        // 2. x0: a write to x0 is ignored, and x0 reads 0 even in the cycle that writes it
        cycle("write x0, read x0",     1'b1, 0, 32'hFFFF_FFFF, 0, 0);
        cycle("x0 after the write",    1'b0, 0, 32'h0000_0000, 0, 0);

        // 3. we = 0 must neither forward wdata nor write it
        cycle("we=0: no write-through", 1'b0, 5, 32'hDEAD_BEEF, 5, 6);
        cycle("we=0: x5 unchanged",     1'b0, 0, 32'h0000_0000, 5, 5);

        // 4. write-through only for the register being written; the other port reads the stored value
        cycle("write x7, read x7 / x8", 1'b1, 7, 32'h1234_5678, 7, 8);
        cycle("write x8, read x7 / x8", 1'b1, 8, 32'h8765_4321, 7, 8);

        // 5. two writes in a row to the same register: each cycle sees its own new value
        cycle("write x9 = AAAA_AAAA",  1'b1, 9, 32'hAAAA_AAAA, 9, 9);
        cycle("write x9 = BBBB_BBBB",  1'b1, 9, 32'hBBBB_BBBB, 9, 9);
        cycle("x9 after both writes",  1'b0, 0, 32'h0000_0000, 9, 9);

        // 6. random cycles; a quarter of the reads use the address being written, so write-through comes up often
        repeat (2000) begin
            r_we  = $urandom_range(0, 1);
            r_wa  = $urandom;
            r_wd  = $urandom;
            r_ra1 = ($urandom_range(0, 3) == 0) ? r_wa : $urandom;
            r_ra2 = ($urandom_range(0, 3) == 0) ? r_wa : $urandom;
            cycle("random", r_we, r_wa, r_wd, r_ra1, r_ra2);
        end

        $display("%0d checks, %0d errors", n_check, errors);
        if (errors == 0) $display("PASS");
        else             $fatal(1, "FAIL");
        $finish;
    end

endmodule