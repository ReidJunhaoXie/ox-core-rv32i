`timescale 1ns/1ps
import core_pkg::*;

module tb_idu ();
    logic [31:0]    instruction; 
    logic [31:0]    pc;
    logic [31:0]    pc_add4;

    id_ex_t  id_ex;      

    logic [4:0]     raddr1 ;       
    logic [4:0]     raddr2 ;

    logic [4:0]     waddr ;
    logic [31:0]    imme_ext ;
    logic [31:0]    pc_out ;
    logic [31:0]    pc_add4_out ;

    idu u0(.instruction(instruction),.pc(pc),.pc_add4(pc_add4),
           .id_ex(id_ex),
           .rf_raddr1(raddr1),.rf_raddr2(raddr2),
           .rf_waddr(waddr),.imme_ext(imme_ext),
           .pc_out(pc_out),.pc_add4_out(pc_add4_out));

    
    initial begin
        $dumpfile("sim/idu_wave.vcd");
        $dumpvars(0,tb_idu);
    end

    /*
    007302B3
    FF058513
    0046A603
    FEE7AC23
    01180863
    FFDFF0EF
    */

    initial begin

        pc = 32'h0000_0000 ;
        pc_add4 = 32'h0000_0004 ;

        $display("IDU Test\n") ;

        // ADD x5, x6, x7 ; 0x007302B3
        $display("add x5, x6, x7");
        instruction = 32'h0073_02b3 ;
        #10 ;
        $display("[ADD] rd:%0d,rs1:%0d,rs2:%0d,rf_wen:%b,alu_ctrl:%4b",
        waddr,raddr1,raddr2,id_ex.rf_wen,id_ex.alu_ctrl);

        // ADDI x10, x11, -16 ; 0xFF058513
        $display("addi x10, x11, -16");
        instruction = 32'hFF05_8513 ;
        #10 ;
        $display("[ADDI] rd:%0d,rs1:%0d,imme_ext:%h,rf_wen:%b,alub_src:%b,alu_ctrl:%4b",
        waddr,raddr1,imme_ext,id_ex.rf_wen,id_ex.alub_src,id_ex.alu_ctrl);

        // LW x12, 4(x13) ; 0x0046A603
        $display("lw x12, 4(x13)");
        instruction = 32'h0046_A603 ;
        #10 ;
        $display("[Load] rd:%0d,rs1:%0d,imme_ext:%h,rf_wen:%b,rf_rd_src:%2b,alub_src:%b,alu_ctrl:%4b",
        waddr,raddr1,imme_ext,id_ex.rf_wen,
        id_ex.rf_rd_src,id_ex.alub_src,id_ex.alu_ctrl);
 
        // SW x14, -8(x15) ; 0xFEE7AC23 SW rf[rs2] mem[rs1-8]
        $display("sw x14, -8(x15)");
        instruction = 32'hFEE7_AC23 ;
        #10 ;
        $display("[Store] rs1:%0d,rs2:%0d,imme_ext:%h,dmem_wen:%b,alub_src:%b,alu_ctrl:%4b",
        raddr1,raddr2,imme_ext,
        id_ex.dm_wen,id_ex.alub_src,id_ex.alu_ctrl);

        // BEQ x16, x17, 16 ; 0x01180863
        $display("beq x16, x17, 16");
        instruction = 32'h0118_0863 ;
        #10 ;
        $display("[Beq] rs1:%0d,rs2:%0d,,jp:%2b,branch:%b,alu_ctrl:%4b",
        raddr1,raddr2,
        id_ex.jp,id_ex.branch,id_ex.alu_ctrl);

        // JAL x1, -4 ; 0xFFDFF0EF
        $display("jal x1, -4");
        instruction = 32'hFFDF_F0EF ;
        #10 ;
        $display("[Jal] rd:%0d,imme_ext:%h,jp:%2b,branch:%b,alu_ctrl:%4b",
        waddr,imme_ext,
        id_ex.jp,id_ex.branch,id_ex.alu_ctrl);

        $finish ;

    end



endmodule