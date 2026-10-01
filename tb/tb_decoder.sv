`timescale 1ns/1ps
import core_pkg::*;

module tb_decoder ();

logic [6:0] opcode ;
logic [2:0] funct3 ;
logic       funct7 ;
logic [3:0] alu_ctrl ;
logic [1:0] alu_op ;

decoder dut (.*) ;

initial begin
    #5 ;
    $display("start decoder test\n") ;

    // first alu_op = 00(+) / funct3(0~7) / funct7(0,1) / opocde[5](0,1) 
    $display("[test1]alu_op=00(+)") ;
    alu_op = 2'b00 ;
    for (int i = 0; i<2 ; i++) begin
        for (int j = 0; j<2 ; j++ ) begin
            for (int k = 0; k<8 ; k++) begin
                funct3 = k ;
                funct7 = j ;
                opcode[5] = i ;
                #1 ;

                if (alu_ctrl!==4'b0000) begin
                    $fatal(1,"test 1 error : opcode_5=%b, funct7=%b, funct3=%b, alu_ctrl=%b",opcode[5], funct7, funct3, alu_ctrl) ;
                end
            end
        end
    end
    $display("[test1]PASS") ;

    // second alu_op = 01(-) / funct3(0~7) / funct7(0,1) / opocde[5](0,1)
    $display("[test2]alu_op=01(-)") ;
    alu_op = 2'b01 ;
    for (int i = 0; i<2 ; i++) begin
        for (int j = 0; j<2 ; j++ ) begin
            for (int k = 0; k<8 ; k++) begin
                funct3 = k ;
                funct7 = j ;
                opcode[5] = i ;
                #1 ;

                if (alu_ctrl!==4'b1000) begin
                    $fatal(1,"test 2 error : opcode_5=%b, funct7=%b, funct3=%b, alu_ctrl=%b",opcode[5], funct7, funct3, alu_ctrl) ;
                end
            end
        end
    end
    $display("[test2]PASS") ;

    // third alu_op = 10(arithem) / funct3(0~7) / funct7(0,1) / opocde[5](0,1)
    $display("[test3]alu_op=10(arithem)") ;
    alu_op = 2'b10 ;
    for (int i = 0; i<2 ; i++) begin
        for (int j = 0; j<2 ; j++ ) begin
            for (int k = 0; k<8 ; k++) begin
                funct3 = k ;
                funct7 = j ;
                opcode[5] = i ;
                #1 ;

                if (alu_ctrl[2:0]!==funct3) begin
                    $fatal(1,"test 3 error : opcode_5=%b, funct7=%b, funct3=%b, alu_ctrl=%b",opcode[5], funct7, funct3, alu_ctrl) ;
                end

                if((funct7&opcode[5]&(alu_ctrl[3]!==1'b1))|((~funct7|~opcode[5])&(alu_ctrl[3]!==1'b0))) begin
                    $fatal(1,"test 3 error : opcode_5=%b, funct7=%b, funct3=%b, alu_ctrl=%b",opcode[5], funct7, funct3, alu_ctrl) ;
                end 
            end
        end
    end
    $display("[test3]PASS") ;
    $finish ;
end

endmodule