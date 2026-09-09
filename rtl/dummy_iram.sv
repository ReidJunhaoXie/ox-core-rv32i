// load package
import core_pkg::*;

module dummy_iram #(
    parameter int A_WIDTH = core_pkg::IRAM_ADDR_WIDTH      // addr width : 12, 12 - 2 = 10 = valid addr width
)(
    input  logic [31:0] pc,
    output logic [31:0] inst
);
    logic [31:0] rom [0:(1<<(A_WIDTH-2))-1];  // 1<<10 => 1 left shift 10bit => 1024

    // EDA load machine code
    initial begin
        $readmemh("test_data/firmware.hex", rom); 
    end

    // Asynchrnous Read
    // lowest 2 bit is invalid
    //=========================================
    assign inst = rom[pc[A_WIDTH-1:2]];    // pc -> rom

endmodule
