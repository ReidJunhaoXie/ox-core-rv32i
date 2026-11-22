    .text
    .globl _start
_start:
    addi x10, x0, 0          # x10, x11 stay 0 only if bne really jumps to skip
    addi x11, x0, 0
    addi x13, x0, 0
    addi x31, x0, 0
    addi x1, x0, 100         # x1  = 100
    addi x2, x0, -7          # x2  = 0xFFFFFFF9
    lui  x3, 0x12345         # x3  = 0x12345000
    nop
    nop
    add  x4, x1, x2          # x4  = 93
    sub  x5, x1, x2          # x5  = 107
    addi x3, x3, 0x678       # x3  = 0x12345678
    nop
    nop
    sw   x3, 0(x0)           # DM word 0 = 0x12345678
    sw   x4, 4(x0)           # DM word 1 = 93
    sw   x2, 8(x0)           # DM word 2 = 0xFFFFFFF9
    lw   x6, 0(x0)           # x6  = 0x12345678
    lb   x7, 3(x0)           # x7  = 0x00000012
    lbu  x8, 0(x0)           # x8  = 0x00000078
    lb   x16, 8(x0)          # x16 = 0xFFFFFFF9
    lhu  x17, 8(x0)          # x17 = 0x0000FFF9
    beq  x1, x2, fail        # not taken
    nop
    nop
    addi x9, x0, 1           # x9  = 1
    bne  x1, x2, skip        # taken
    nop
    nop
    addi x10, x0, 1          # skipped by bne
    addi x11, x0, 1          # skipped by bne
skip:
    jal  x12, func           # x12 = address of the nop below
    nop
    nop
    addi x13, x0, 1          # x13 = 1, runs only after func returns
    j    done
    nop
    nop
func:
    addi x14, x0, 55         # x14 = 55
    nop
    nop
    jalr x0, 0(x12)          # return
    nop
    nop
done:
    auipc x15, 0             # x15 = address of this instruction
end:
    j    end
    nop
    nop
fail:
    addi x31, x0, 1          # reached only if beq is wrongly taken
    j    end
    nop
    nop