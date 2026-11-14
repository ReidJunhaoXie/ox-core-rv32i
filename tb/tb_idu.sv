// tb_idu.sv : idu testbench (decoder + imme_gen), directed + random instructions
//   iverilog -g2012 -o sim/sim.out rtl/core_pkg.sv rtl/decoder.sv rtl/imme_gen.sv rtl/idu.sv tb/tb_idu.sv
//   vvp sim/sim.out
`timescale 1ns/1ps

module tb_idu;
    import core_pkg::*;

    // signals with the same names as the idu ports
    logic [31:0] instruction;
    id_ex_t      id_ex;
    logic [4:0]  rf_raddr1, rf_raddr2, rf_waddr;
    logic [31:0] imme_ext;
    logic [31:0] pc;        // idu no longer uses pc; kept so .* still finds a match while idu has a pc port

    idu dut (.*);       // signal names match the port names, so .* connects them automatically

    int errors = 0;
    int n_test = 0;

    // ------------------------------------------------------------------
    // Instruction builders: place each field where the spec puts it, like an assembler.
    // The immediate goes in as a plain number and the builder scatters its bits,
    // so a test can check that imme_ext gives back exactly that number.
    // ------------------------------------------------------------------
    function automatic logic [31:0] r_type(input logic [6:0] f7, input logic [2:0] f3,
                                           input logic [4:0] rd, rs1, rs2);
        return {f7, rs2, rs1, f3, rd, OP_R_TYPE};
    endfunction

    // I-type: OP-IMM, load and JALR share this format (the opcode tells them apart)
    function automatic logic [31:0] i_type(input logic [6:0] opcode, input logic [2:0] f3,
                                           input logic [4:0] rd, rs1, input logic [11:0] imm);
        return {imm, rs1, f3, rd, opcode};
    endfunction

    function automatic logic [31:0] s_type(input logic [2:0] f3, input logic [4:0] rs1, rs2,
                                           input logic [11:0] imm);
        return {imm[11:5], rs2, rs1, f3, imm[4:0], OP_STORE};
    endfunction

    // offset in bytes, always even: bit 0 is not stored in the instruction
    function automatic logic [31:0] b_type(input logic [2:0] f3, input logic [4:0] rs1, rs2,
                                           input logic [12:0] offset);
        return {offset[12], offset[10:5], rs2, rs1, f3, offset[4:1], offset[11], OP_BRANCH};
    endfunction

    // LUI and AUIPC: imm20 becomes bits 31:12 of the immediate
    function automatic logic [31:0] u_type(input logic [6:0] opcode, input logic [4:0] rd,
                                           input logic [19:0] imm20);
        return {imm20, rd, opcode};
    endfunction

    // offset in bytes, always even
    function automatic logic [31:0] j_type(input logic [4:0] rd, input logic [20:0] offset);
        return {offset[20], offset[10:1], offset[11], offset[19:12], rd, OP_JAL};
    endfunction

    // sign-extend the low `bits` bits of value to 32 bits
    function automatic logic [31:0] sext(input logic [31:0] value, input int bits);
        return $signed(value << (32 - bits)) >>> (32 - bits);
    endfunction

    // ------------------------------------------------------------------
    // Reference model: the control signals each instruction type should produce.
    // Written as a table from the spec and the core_pkg encodings, not from the decoder logic.
    // x = don't care: that field is not checked for this instruction.
    // ------------------------------------------------------------------
    localparam logic [3:0] ALU_ADD = 4'b0000;
    localparam logic [3:0] ALU_SUB = 4'b1000;

    function automatic id_ex_t ref_ctrl(input logic [31:0] ins);
        id_ex_t     e;
        logic [2:0] f3;
        logic       alt;                         // instr[30]: picks SUB, SRA and SRAI
        f3  = ins[14:12];
        alt = ins[30];

        e        = 'x;                           // every field starts as don't care
        e.funct3 = f3;                           // funct3 is always passed on unchanged
        e.jp     = JP_ADD4;                      // these four matter for every instruction:
        e.branch = 1'b0;                         // no jump, no branch and no writes
        e.rf_wen = 1'b0;                         // unless the instruction sets them below
        e.dm_wen = 1'b0;

        case (ins[6:0])
            OP_R_TYPE: begin                     // rd = rs1 op rs2
                e.rf_wen   = 1'b1;     e.rf_rd_src = RD_ALU;
                e.alua_src = ALUA_RF;  e.alub_src  = ALUB_RF;
                e.alu_ctrl = {alt, f3};
            end
            OP_I_TYPE: begin                     // rd = rs1 op imm; only SRAI uses instr[30]
                e.rf_wen   = 1'b1;     e.rf_rd_src = RD_ALU;
                e.alua_src = ALUA_RF;  e.alub_src  = ALUB_IMME;
                e.alu_ctrl = {(f3 == 3'b101) ? alt : 1'b0, f3};
            end
            OP_LOAD: begin                       // rd = mem[rs1 + imm]
                e.rf_wen   = 1'b1;     e.rf_rd_src = RD_DM;
                e.alua_src = ALUA_RF;  e.alub_src  = ALUB_IMME;  e.alu_ctrl = ALU_ADD;
            end
            OP_STORE: begin                      // mem[rs1 + imm] = rs2
                e.dm_wen   = 1'b1;
                e.alua_src = ALUA_RF;  e.alub_src  = ALUB_IMME;  e.alu_ctrl = ALU_ADD;
            end
            OP_BRANCH: begin                     // compare rs1 - rs2, target pc + imm
                e.branch   = 1'b1;
                e.alua_src = ALUA_RF;  e.alub_src  = ALUB_RF;    e.alu_ctrl = ALU_SUB;
            end
            OP_JAL: begin                        // rd = pc + 4, pc = pc + imm (the ALU is not used)
                e.jp       = JP_ADDI;  e.rf_wen    = 1'b1;       e.rf_rd_src = RD_PC;
            end
            OP_JALR: begin                       // rd = pc + 4, pc = rs1 + imm
                e.jp       = JP_ALU;   e.rf_wen    = 1'b1;       e.rf_rd_src = RD_PC;
                e.alua_src = ALUA_RF;  e.alub_src  = ALUB_IMME;  e.alu_ctrl  = ALU_ADD;
            end
            OP_LUI: begin                        // rd = 0 + imm
                e.rf_wen   = 1'b1;       e.rf_rd_src = RD_ALU;
                e.alua_src = ALUA_ZERO;  e.alub_src  = ALUB_IMME;  e.alu_ctrl = ALU_ADD;
            end
            OP_AUIPC: begin                      // rd = pc + imm
                e.rf_wen   = 1'b1;       e.rf_rd_src = RD_ALU;
                e.alua_src = ALUA_PC;    e.alub_src  = ALUB_IMME;  e.alu_ctrl = ALU_ADD;
            end
            default: ;                           // not supported (FENCE, ECALL, ...): must act as a NOP
        endcase
        return e;
    endfunction

    // ------------------------------------------------------------------
    // Test task: decode one instruction and check every idu output
    //   exp_imm = 'x when the instruction has no immediate (R-type, unsupported)
    // ------------------------------------------------------------------
    task automatic check(input string name, input logic [31:0] ins, input logic [31:0] exp_imm);
        id_ex_t exp;
        exp         = ref_ctrl(ins);
        instruction = ins;
        pc          = $urandom;                  // idu does not use pc: a random value shows no output depends on it
        #1;
        n_test++;
        // ==? skips the bits that are x in the expected value.
        // "!== 1'b1" also fails when the DUT itself outputs x on a checked bit.
        if ((id_ex ==? exp) !== 1'b1 || (imme_ext ==? exp_imm) !== 1'b1 ||
            rf_raddr1 !== ins[19:15] || rf_raddr2 !== ins[24:20] || rf_waddr !== ins[11:7]) begin
            errors++;
            if (errors <= 10) begin
                $display("[FAIL] %s (instruction %h)", name, ins);
                $display("   got jp=%b branch=%b rf_wen=%b dm_wen=%b rf_rd_src=%b alub=%b alua=%b alu_ctrl=%b funct3=%b imm=%h",
                         id_ex.jp, id_ex.branch, id_ex.rf_wen, id_ex.dm_wen, id_ex.rf_rd_src,
                         id_ex.alub_src, id_ex.alua_src, id_ex.alu_ctrl, id_ex.funct3, imme_ext);
                $display("   exp jp=%b branch=%b rf_wen=%b dm_wen=%b rf_rd_src=%b alub=%b alua=%b alu_ctrl=%b funct3=%b imm=%h  (x = not checked)",
                         exp.jp, exp.branch, exp.rf_wen, exp.dm_wen, exp.rf_rd_src,
                         exp.alub_src, exp.alua_src, exp.alu_ctrl, exp.funct3, exp_imm);
                $display("   got rs1=%0d rs2=%0d rd=%0d, exp rs1=%0d rs2=%0d rd=%0d",
                         rf_raddr1, rf_raddr2, rf_waddr, ins[19:15], ins[24:20], ins[11:7]);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Random legal instructions
    // ------------------------------------------------------------------

    // legal funct3 values (Icarus has no array literals, so pick with a case)
    function automatic logic [2:0] rand_load_f3();
        case ($urandom_range(0, 4))
            0: return 3'b000;   1: return 3'b001;   2: return 3'b010;     // lb  lh  lw
            3: return 3'b100;   default: return 3'b101;                   // lbu lhu
        endcase
    endfunction

    function automatic logic [2:0] rand_branch_f3();
        case ($urandom_range(0, 5))
            0: return 3'b000;   1: return 3'b001;   2: return 3'b100;     // beq  bne  blt
            3: return 3'b101;   4: return 3'b110;   default: return 3'b111;  // bge  bltu bgeu
        endcase
    endfunction

    // any opcode the core does not support; it must behave as a NOP
    function automatic logic [6:0] rand_unsupported_opcode();
        logic [6:0] op;
        do op = $urandom;
        while (op == OP_R_TYPE || op == OP_I_TYPE || op == OP_LOAD || op == OP_STORE || op == OP_BRANCH ||
               op == OP_JAL    || op == OP_JALR   || op == OP_LUI  || op == OP_AUIPC);
        return op;
    endfunction

    // one random instruction of every type per round: random registers, funct3 and immediate
    task automatic random_tests(input int rounds);
        logic [4:0]  rd, rs1, rs2;
        logic [2:0]  f3;
        logic [6:0]  f7;
        logic [31:0] imm;                        // random value; each format uses its own low bits
        repeat (rounds) begin
            rd  = $urandom;   rs1 = $urandom;   rs2 = $urandom;

            // R-type: funct7 can be 0x20 only for SUB and SRA
            f3 = $urandom;
            f7 = ((f3 == 3'b000 || f3 == 3'b101) && $urandom_range(0, 1)) ? 7'h20 : 7'h00;
            check("random R-type", r_type(f7, f3, rd, rs1, rs2), 'x);

            // OP-IMM: shifts keep a fixed imm[11:5] (0x00, or 0x20 for SRAI); the others use any 12-bit value
            f3  = $urandom;
            imm = $urandom;
            if (f3 == 3'b001)      imm[11:5] = 7'h00;
            else if (f3 == 3'b101) imm[11:5] = $urandom_range(0, 1) ? 7'h20 : 7'h00;
            check("random OP-IMM", i_type(OP_I_TYPE, f3, rd, rs1, imm[11:0]), sext(imm, 12));

            imm = $urandom;
            check("random load",   i_type(OP_LOAD, rand_load_f3(), rd, rs1, imm[11:0]), sext(imm, 12));
            check("random store",  s_type(3'($urandom_range(0, 2)), rs1, rs2, imm[11:0]), sext(imm, 12));
            check("random branch", b_type(rand_branch_f3(), rs1, rs2, {imm[12:1], 1'b0}),
                                   sext({imm[12:1], 1'b0}, 13));
            check("random jal",    j_type(rd, {imm[20:1], 1'b0}), sext({imm[20:1], 1'b0}, 21));
            check("random jalr",   i_type(OP_JALR, 3'b000, rd, rs1, imm[11:0]), sext(imm, 12));
            check("random lui",    u_type(OP_LUI,   rd, imm[31:12]), {imm[31:12], 12'b0});
            check("random auipc",  u_type(OP_AUIPC, rd, imm[31:12]), {imm[31:12], 12'b0});
            check("random unsupported opcode", {imm[31:7], rand_unsupported_opcode()}, 'x);
        end
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    initial begin
        // 1. directed: every RV32I instruction at least once, with edge-case immediates
        //    registers: rd = x1, rs1 = x2, rs2 = x3 (all different, so a swapped field shows up)

        // R-type
        check("add  x1, x2, x3",  r_type(7'h00, 3'b000, 5'd1, 5'd2, 5'd3), 'x);
        check("sub  x1, x2, x3",  r_type(7'h20, 3'b000, 5'd1, 5'd2, 5'd3), 'x);
        check("sll  x1, x2, x3",  r_type(7'h00, 3'b001, 5'd1, 5'd2, 5'd3), 'x);
        check("slt  x1, x2, x3",  r_type(7'h00, 3'b010, 5'd1, 5'd2, 5'd3), 'x);
        check("sltu x1, x2, x3",  r_type(7'h00, 3'b011, 5'd1, 5'd2, 5'd3), 'x);
        check("xor  x1, x2, x3",  r_type(7'h00, 3'b100, 5'd1, 5'd2, 5'd3), 'x);
        check("srl  x1, x2, x3",  r_type(7'h00, 3'b101, 5'd1, 5'd2, 5'd3), 'x);
        check("sra  x1, x2, x3",  r_type(7'h20, 3'b101, 5'd1, 5'd2, 5'd3), 'x);
        check("or   x1, x2, x3",  r_type(7'h00, 3'b110, 5'd1, 5'd2, 5'd3), 'x);
        check("and  x1, x2, x3",  r_type(7'h00, 3'b111, 5'd1, 5'd2, 5'd3), 'x);

        // OP-IMM
        check("addi  x1, x2, -1",     i_type(OP_I_TYPE, 3'b000, 5'd1, 5'd2, 12'hFFF), 32'hFFFF_FFFF);
        check("addi  x1, x2, 0x400",  i_type(OP_I_TYPE, 3'b000, 5'd1, 5'd2, 12'h400), 32'h0000_0400);  // instr[30] = 1, must stay ADD
        check("slti  x1, x2, 2047",   i_type(OP_I_TYPE, 3'b010, 5'd1, 5'd2, 12'h7FF), 32'h0000_07FF);  // largest positive
        check("sltiu x1, x2, -2048",  i_type(OP_I_TYPE, 3'b011, 5'd1, 5'd2, 12'h800), 32'hFFFF_F800);  // sltiu also sign-extends
        check("xori  x1, x2, 0x555",  i_type(OP_I_TYPE, 3'b100, 5'd1, 5'd2, 12'h555), 32'h0000_0555);
        check("ori   x1, x2, -1366",  i_type(OP_I_TYPE, 3'b110, 5'd1, 5'd2, 12'hAAA), 32'hFFFF_FAAA);
        check("andi  x1, x2, 0xFF",   i_type(OP_I_TYPE, 3'b111, 5'd1, 5'd2, 12'h0FF), 32'h0000_00FF);
        check("slli  x1, x2, 31",     i_type(OP_I_TYPE, 3'b001, 5'd1, 5'd2, {7'h00, 5'd31}), 32'h0000_001F);
        check("srli  x1, x2, 31",     i_type(OP_I_TYPE, 3'b101, 5'd1, 5'd2, {7'h00, 5'd31}), 32'h0000_001F);
        check("srai  x1, x2, 4",      i_type(OP_I_TYPE, 3'b101, 5'd1, 5'd2, {7'h20, 5'd4}),  32'h0000_0404);  // instr[30] = 1, must be SRA

        // load
        check("lb  x1, -2048(x2)",  i_type(OP_LOAD, 3'b000, 5'd1, 5'd2, 12'h800), 32'hFFFF_F800);
        check("lh  x1, 2047(x2)",   i_type(OP_LOAD, 3'b001, 5'd1, 5'd2, 12'h7FF), 32'h0000_07FF);
        check("lw  x1, 8(x2)",      i_type(OP_LOAD, 3'b010, 5'd1, 5'd2, 12'h008), 32'h0000_0008);
        check("lbu x1, -1(x2)",     i_type(OP_LOAD, 3'b100, 5'd1, 5'd2, 12'hFFF), 32'hFFFF_FFFF);
        check("lhu x1, 0(x2)",      i_type(OP_LOAD, 3'b101, 5'd1, 5'd2, 12'h000), 32'h0000_0000);

        // store: the immediate is split into instr[31:25] and instr[11:7]
        check("sb x3, -2048(x2)",   s_type(3'b000, 5'd2, 5'd3, 12'h800), 32'hFFFF_F800);
        check("sh x3, 2047(x2)",    s_type(3'b001, 5'd2, 5'd3, 12'h7FF), 32'h0000_07FF);
        check("sw x3, -4(x2)",      s_type(3'b010, 5'd2, 5'd3, 12'hFFC), 32'hFFFF_FFFC);

        // branch: offsets at both ends of the range, and ones that need offset bit 11 (stored in instr[7])
        check("beq  x2, x3, -4096", b_type(3'b000, 5'd2, 5'd3, 13'h1000), 32'hFFFF_F000);
        check("bne  x2, x3, +4094", b_type(3'b001, 5'd2, 5'd3, 13'h0FFE), 32'h0000_0FFE);
        check("blt  x2, x3, -2",    b_type(3'b100, 5'd2, 5'd3, 13'h1FFE), 32'hFFFF_FFFE);
        check("bge  x2, x3, +2048", b_type(3'b101, 5'd2, 5'd3, 13'h0800), 32'h0000_0800);
        check("bltu x2, x3, +16",   b_type(3'b110, 5'd2, 5'd3, 13'h0010), 32'h0000_0010);
        check("bgeu x2, x3, -2048", b_type(3'b111, 5'd2, 5'd3, 13'h1800), 32'hFFFF_F800);

        // jumps: J-type offsets at both ends, and ones that need bit 11 (instr[20]) and bit 12 (instr[12])
        check("jal  x1, -1 MiB",     j_type(5'd1, 21'h10_0000), 32'hFFF0_0000);
        check("jal  x0, +1 MiB - 2", j_type(5'd0, 21'h0F_FFFE), 32'h000F_FFFE);
        check("jal  x1, +2048",      j_type(5'd1, 21'h00_0800), 32'h0000_0800);
        check("jal  x1, +4096",      j_type(5'd1, 21'h00_1000), 32'h0000_1000);
        check("jalr x1, -1(x2)",     i_type(OP_JALR, 3'b000, 5'd1, 5'd2, 12'hFFF), 32'hFFFF_FFFF);
        check("jalr x0, 0(x1)",      i_type(OP_JALR, 3'b000, 5'd0, 5'd1, 12'h000), 32'h0000_0000);   // ret

        // U-type: instr[14:12] is part of the immediate here, not a funct3
        check("lui   x5, 0x12345",  u_type(OP_LUI,   5'd5, 20'h12345), 32'h1234_5000);   // instr[14:12] = 101
        check("lui   x5, 0xFFFFF",  u_type(OP_LUI,   5'd5, 20'hFFFFF), 32'hFFFF_F000);
        check("auipc x1, 0x23",     u_type(OP_AUIPC, 5'd1, 20'h00023), 32'h0002_3000);   // instr[14:12] = 011
        check("auipc x1, 0x80000",  u_type(OP_AUIPC, 5'd1, 20'h80000), 32'h8000_0000);

        // not supported: must act as a NOP
        check("fence",  32'h0FF0_000F, 'x);
        check("ecall",  32'h0000_0073, 'x);
        check("ebreak", 32'h0010_0073, 'x);

        // 2. random legal instructions (10 types per round)
        random_tests(500);

        $display("%0d tests, %0d errors", n_test, errors);
        if (errors == 0) $display("PASS");
        else             $fatal(1, "FAIL");
        $finish;
    end

endmodule