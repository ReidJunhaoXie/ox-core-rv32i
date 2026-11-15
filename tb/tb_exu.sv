// tb_exu.sv : exu testbench (directed tests + reference model)
//   iverilog -g2012 -o sim/sim.out rtl/core_pkg.sv rtl/shifter.sv rtl/alu_adder.sv rtl/alu.sv rtl/exu.sv tb/tb_exu.sv
//   vvp sim/sim.out
`timescale 1ns/1ps

module tb_exu;
    import core_pkg::*;

    // signals with the same names as the exu ports
    logic [31:0] rf_rdata1, rf_rdata2, imme_ext, pc_in;
    logic [2:0]  funct3;
    logic [3:0]  alu_ctrl;
    jp_t         jp;
    logic        branch;
    alub_src_t   alub_src;      // ALU B input: rs2 or imm
    alua_src_t   alua_src;      // ALU A input: rs1, 0 (LUI) or pc (AUIPC)
    pc_src_t     pc_src;
    logic [31:0] alu_out, pc_adder_out, pc_add4;

    exu dut (.*);       // signal names match the port names, so .* connects them automatically

    int errors = 0;

    // ------------------------------------------------------------------
    // Reference model: computes the expected result from the spec with plain SystemVerilog operators (not a copy of the RTL)
    // ------------------------------------------------------------------

    // correct ALU result; ctrl follows the alu_ctrl encoding {instr[30], funct3}
    function automatic logic [31:0] ref_alu(input logic [3:0]  ctrl,
                                            input logic [31:0] a,     // rs1
                                            input logic [31:0] b);    // rs2 or imm
        logic [4:0] shamt;
        shamt = b[4:0];                                               // shift amount uses only the low 5 bits
        case (ctrl[2:0])
            3'b000 : ref_alu = ctrl[3] ? a - b : a + b;                       // ADD / SUB
            3'b001 : ref_alu = a << shamt;                                    // SLL
            3'b010 : ref_alu = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;     // SLT
            3'b011 : ref_alu = (a < b) ? 32'd1 : 32'd0;                       // SLTU
            3'b100 : ref_alu = a ^ b;                                         // XOR
            3'b101 : begin                                                    // SRL / SRA
                // keep this as if/else: in a one-line ?: the unsigned branch turns >>> into a logical shift
                if (ctrl[3]) ref_alu = $signed(a) >>> shamt;
                else         ref_alu = a >> shamt;
            end
            3'b110 : ref_alu = a | b;                                         // OR
            default: ref_alu = a & b;                                         // AND
        endcase
    endfunction

    // whether the branch should be taken
    function automatic logic ref_taken(input logic [2:0]  f3,
                                       input logic [31:0] a,      // rs1
                                       input logic [31:0] b);     // rs2
        case (f3)
            3'b000 : ref_taken = (a == b);                       // BEQ
            3'b001 : ref_taken = (a != b);                       // BNE
            3'b100 : ref_taken = ($signed(a) <  $signed(b));     // BLT
            3'b101 : ref_taken = ($signed(a) >= $signed(b));     // BGE
            3'b110 : ref_taken = (a <  b);                       // BLTU
            3'b111 : ref_taken = (a >= b);                       // BGEU
            default: ref_taken = 1'b0;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Test tasks
    // ------------------------------------------------------------------

    // pc does not affect the ALU result, but it gets a new random value on every test
    // so that every bit of pc_adder_out and pc_add4 is actually checked
    task automatic random_pc();
        pc_in = $urandom & 32'hFFFF_FFFC;   // 4-byte aligned
    endtask

    // outputs checked on every test: the jump target pc + imm and the return address pc + 4
    task automatic check_common(input string name);
        if (pc_adder_out !== pc_in + imme_ext || pc_add4 !== pc_in + 32'd4) begin
            errors++;
            $display("[FAIL] %s : pc_in = %h, pc_adder_out = %h, pc_add4 = %h",
                     name, pc_in, pc_adder_out, pc_add4);
        end
    endtask

    // one ALU operation: apply controls and operands, check alu_out, and make sure no jump is taken
    task automatic alu_test(input string       name,
                            input logic [3:0]  ctrl,      // alu_ctrl
                            input logic        src,       // 1 = imm, 0 = rs2
                            input logic [31:0] rs1, rs2, imm);
        logic [31:0] expected;
        expected  = ref_alu(ctrl, rs1, src ? imm : rs2);   // expected value from the reference model
        random_pc();

        rf_rdata1 = rs1;
        rf_rdata2 = rs2;
        imme_ext  = imm;
        alu_ctrl  = ctrl;
        if (src) alub_src = ALUB_IMME;
        else     alub_src = ALUB_RF;
        alua_src  = ALUA_RF;
        funct3    = ctrl[2:0];   // for ALU instructions, funct3 = alu_ctrl[2:0]
        branch    = 1'b0;
        jp        = JP_ADD4;
        #1;
        if (alu_out !== expected || pc_src !== PC_ADD4) begin
            errors++;
            $display("[FAIL] %s : alu_out = %h (expected %h), pc_src = %b",
                     name, alu_out, expected, pc_src);
        end
        check_common(name);
    endtask

    // one branch: apply funct3 and two registers; pc_src must be PC_ADDI if taken, PC_ADD4 if not
    // (the branch flag stays inside exu, so pc_src is where the decision shows up)
    task automatic branch_test(input string       name,
                               input logic [2:0]  f3,
                               input logic [31:0] rs1, rs2);
        logic    taken;
        pc_src_t expected;
        taken = ref_taken(f3, rs1, rs2);                   // expected value from the reference model
        if (taken) expected = PC_ADDI;
        else       expected = PC_ADD4;
        random_pc();

        rf_rdata1 = rs1;
        rf_rdata2 = rs2;
        imme_ext  = 32'h10;
        alu_ctrl  = 4'b1000;     // branches always subtract
        alub_src  = ALUB_RF;     // compare rs1 with rs2
        alua_src  = ALUA_RF;
        funct3    = f3;
        branch    = 1'b1;
        jp        = JP_ADD4;
        #1;
        if (pc_src !== expected) begin
            errors++;
            $display("[FAIL] %s : pc_src = %b (expected %b, taken = %b)",
                     name, pc_src, expected, taken);
        end
        check_common(name);
    endtask

    // one jump: check pc_src; for JALR also check alu_out = rs1 + imm (bit 0 is cleared in IF)
    task automatic jump_test(input string       name,
                             input jp_t         j,         // JP_ADDI = JAL, JP_ALU = JALR
                             input logic [31:0] rs1, imm);
        pc_src_t expected;
        if (j == JP_ALU) expected = PC_ALU;                // JALR: target from the ALU
        else             expected = PC_ADDI;               // JAL : target pc + imm
        random_pc();

        rf_rdata1 = rs1;
        rf_rdata2 = 32'd0;
        imme_ext  = imm;
        alu_ctrl  = 4'b0000;     // JALR target = rs1 + imm
        alub_src  = ALUB_IMME;
        alua_src  = ALUA_RF;
        funct3    = 3'b000;
        branch    = 1'b0;
        jp        = j;
        #1;
        if (pc_src !== expected || (j == JP_ALU && alu_out !== rs1 + imm)) begin
            errors++;
            $display("[FAIL] %s : pc_src = %b (expected %b), alu_out = %h", name, pc_src, expected, alu_out);
        end
        check_common(name);
    endtask

    // LUI / AUIPC: ALU A takes 0 or pc instead of rs1, so the junk in rs1 must not reach the result
    task automatic upper_test(input string       name,
                              input alua_src_t   a_src,     // ALUA_ZERO = LUI, ALUA_PC = AUIPC
                              input logic [31:0] imm);      // U-type immediate: {imm20, 12'b0}
        logic [31:0] expected;
        random_pc();
        expected  = (a_src == ALUA_PC) ? pc_in + imm : imm;

        rf_rdata1 = 32'hDEAD_BEEF;   // junk: LUI and AUIPC have no rs1
        rf_rdata2 = $urandom;
        imme_ext  = imm;
        alu_ctrl  = 4'b0000;         // add
        alub_src  = ALUB_IMME;
        alua_src  = a_src;
        funct3    = imm[14:12];      // instr[14:12] is part of the immediate, the decoder passes it on anyway
        branch    = 1'b0;
        jp        = JP_ADD4;
        #1;
        if (alu_out !== expected || pc_src !== PC_ADD4) begin
            errors++;
            $display("[FAIL] %s : alu_out = %h (expected %h), pc_src = %b", name, alu_out, expected, pc_src);
        end
        check_common(name);
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    initial begin
        //       name              alu_ctrl src rs1            rs2            imm
        alu_test("ADD wrap",        4'b0000, 0, 32'hFFFF_FFFF, 32'd1,         32'd0);
        alu_test("SUB 3 - 5",       4'b1000, 0, 32'd3,         32'd5,         32'd0);
        alu_test("ADDI 5 + (-6)",   4'b0000, 1, 32'd5,         32'd0,         32'hFFFF_FFFA);
        alu_test("SLT 3 < 5",       4'b0010, 0, 32'd3,         32'd5,         32'd0);
        alu_test("SLT MAX < 1",     4'b0010, 0, 32'h7FFF_FFFF, 32'd1,         32'd0);
        alu_test("SLT 1 < MAX",     4'b0010, 0, 32'd1,         32'h7FFF_FFFF, 32'd0);
        alu_test("SLT -1 < 1",      4'b0010, 0, 32'hFFFF_FFFF, 32'd1,         32'd0);
        alu_test("SLTU FFFFFFFF<1", 4'b0011, 0, 32'hFFFF_FFFF, 32'd1,         32'd0);
        alu_test("SLTU 1<FFFFFFFF", 4'b0011, 0, 32'd1,         32'hFFFF_FFFF, 32'd0);
        alu_test("SLT MAX < -1",    4'b0010, 0, 32'h7FFF_FFFF, 32'hFFFF_FFFF, 32'd0);
        alu_test("SLT MIN < 1",     4'b0010, 0, 32'h8000_0000, 32'd1,         32'd0);
        alu_test("XOR",             4'b0100, 0, 32'hFF00_FF00, 32'h0FF0_0FF0, 32'd0);
        alu_test("OR",              4'b0110, 0, 32'hFF00_FF00, 32'h0FF0_0FF0, 32'd0);
        alu_test("AND",             4'b0111, 0, 32'hFF00_FF00, 32'h0FF0_0FF0, 32'd0);
        alu_test("SLL rs2 = 33",    4'b0001, 0, 32'h8000_0001, 32'd33,        32'd0);
        alu_test("SRA positive",    4'b1101, 0, 32'h7000_0000, 32'd4,         32'd0);
        alu_test("SRAI imm = 0x404",4'b1101, 1, 32'hF000_0000, 32'd0,         32'h0000_0404);

        // every shift amount from 0 to 31
        for (int s = 0; s < 32; s++) begin
            alu_test("SLL sweep", 4'b0001, 0, 32'h8765_4321, s, 32'd0);
            alu_test("SRL sweep", 4'b0101, 0, 32'h8765_4321, s, 32'd0);
            alu_test("SRA sweep", 4'b1101, 0, 32'h8765_4321, s, 32'd0);
        end

        // every branch type is tested both taken and not taken
        //          name                funct3  rs1            rs2                 result
        branch_test("BEQ 5, 5",         3'b000, 32'd5,         32'd5);          // taken
        branch_test("BEQ 5, 6",         3'b000, 32'd5,         32'd6);          // not taken
        branch_test("BEQ 10000000, 0",  3'b000, 32'h1000_0000, 32'd0);          // not taken, differs only in the high bits
        branch_test("BNE 5, 5",         3'b001, 32'd5,         32'd5);          // not taken
        branch_test("BNE 10000000, 0",  3'b001, 32'h1000_0000, 32'd0);          // taken, differs only in the high bits
        branch_test("BLT MAX, -1",      3'b100, 32'h7FFF_FFFF, 32'hFFFF_FFFF);  // not taken
        branch_test("BLT MIN, 1",       3'b100, 32'h8000_0000, 32'd1);          // taken
        branch_test("BGE MIN, MIN",     3'b101, 32'h8000_0000, 32'h8000_0000);  // taken
        branch_test("BGE -1, 1",        3'b101, 32'hFFFF_FFFF, 32'd1);          // not taken
        branch_test("BLTU 1, FFFFFFFF", 3'b110, 32'd1,         32'hFFFF_FFFF);  // taken
        branch_test("BLTU FFFFFFFF, 1", 3'b110, 32'hFFFF_FFFF, 32'd1);          // not taken
        branch_test("BGEU 0, 0",        3'b111, 32'd0,         32'd0);          // taken
        branch_test("BGEU 1, FFFFFFFF", 3'b111, 32'd1,         32'hFFFF_FFFF);  // not taken

        //        name          jp       rs1            imm
        jump_test("JAL",        JP_ADDI, 32'd0,         32'hFFFF_F000);
        jump_test("JALR odd",   JP_ALU,  32'h0000_1001, 32'd0);

        //         name             ALU A      imm
        upper_test("LUI 0x12345",   ALUA_ZERO, 32'h1234_5000);
        upper_test("LUI 0xFFFFF",   ALUA_ZERO, 32'hFFFF_F000);
        upper_test("AUIPC 0x23",    ALUA_PC,   32'h0002_3000);
        upper_test("AUIPC 0x80000", ALUA_PC,   32'h8000_0000);

        if (errors == 0) $display("PASS");
        else             $fatal(1, "FAIL: %0d errors", errors);
        $finish;
    end

endmodule