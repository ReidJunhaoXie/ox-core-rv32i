
package core_pkg;

    // local parameter ====================================================
    localparam int XLEN = 32;
    localparam int REG_ADDR_WIDTH = 5;
    localparam int IRAM_ADDR_WIDTH = 12;
    localparam int DRAM_ADDR_WIDTH = 12;

    // PC Source 
    typedef enum logic [1:0] {
        PC_ADD4 = 2'b00 ,
        PC_ADDI = 2'b01 ,
        PC_ALU  = 2'b10 
    } pc_src_t;

    // Immediate Source
    typedef enum logic [2:0] {
        IMM_I   = 3'b000,
        IMM_S   = 3'b001,
        IMM_B   = 3'b010,
        IMM_J   = 3'b011,
        IMM_U   = 3'b100 
    } imme_src_t;

    // RF Source
    typedef enum logic [1:0] { 
        RD_DM   = 2'b00,
        RD_ALU  = 2'b01,
        RD_PC   = 2'b10
    } rd_src_t;

    // Alu b Source
    typedef enum logic {
        ALUB_RF     = 1'b0,
        ALUB_IMME   = 1'b1 
    } alub_src_t;

    // Main de tp ALU de: ALU_op sepetate funct3 function=============================
    typedef enum logic [1:0] {
        ALUOP_MEM       = 2'b00,  // MEMORY
        ALUOP_BRANCH    = 2'b01,  // Compare condition
        ALUOP_ARITHEM   = 2'b10   // Arithem 
    } alu_op_t;

//ALU de to ALU : control ALU=====================================
    typedef enum logic [3:0] {

        ALU_ADD  = 4'b0000, // funct3:000 
        ALU_SLL  = 4'b0001, // funct3:001 
        ALU_SLT  = 4'b0010, // funct3:010 
        ALU_SLTU = 4'b0011, // funct3:011 
        ALU_XOR  = 4'b0100, // funct3:100 
        ALU_SRL  = 4'b0101, // funct3:101 
        ALU_OR   = 4'b0110, // funct3:110 
        ALU_AND  = 4'b0111, // funct3:111

        ALU_SUB  = 4'b1000, // funct3:000 (R-Type減法 / Branch強制減法比較)
        ALU_SRA  = 4'b1101  // funct3:101 (算術右移)
    } alu_ctrl_t;

    //opcode====================================================
    localparam logic [6:0] OP_R_TYPE    = 7'b0110011;  // R
    localparam logic [6:0] OP_I_TYPE    = 7'b0010011;  // I(except load and jalr)
    localparam logic [6:0] OP_LOAD      = 7'b0000011;  // I-load
    localparam logic [6:0] OP_STORE     = 7'b0100011;  // S
    localparam logic [6:0] OP_BRANCH    = 7'b1100011;  // B
    localparam logic [6:0] OP_JAL       = 7'b1101111;  // J
    localparam logic [6:0] OP_JALR      = 7'b1100111;  // I-jalr
    localparam logic [6:0] OP_LUI       = 7'b0110111;  // U
    localparam logic [6:0] OP_AUIPC     = 7'b0010111;  // U




    // Packed Structs : pipeline signal group===========================
    // IF to ID singal group
    typedef struct packed {
        logic [XLEN-1:0] pc;
        logic [31:0] inst;
    } if_id_t;

    // ID to EX signal group
    typedef struct packed {
        logic [XLEN-1:0] pc;          
        logic [XLEN-1:0] rdata1;      // --> ALU_in1
        logic [XLEN-1:0] rdata2;      // --> ALU_in1 or D_RAM
        logic [XLEN-1:0] imm;         // immediate
        logic [REG_ADDR_WIDTH-1:0]  rd;          // rd
        
        
        // control signal
        logic        alu_src;     
        logic        [1:0]result_src;      
        
        alu_op_t     alu_ctrl;    
        
        logic        mem_write;   
        logic        mem_read;   
        logic        reg_write;   
    } id_ex_t;

    // EX to MEM signal group
    typedef struct packed {
        logic [XLEN-1:0] alu_result;  // ALU out
        logic [XLEN-1:0] mem_wdata;   // rdata_2
        logic [4:0]  rd;          // rd
        
        // control signal
        logic        [1:0]result_src;
        logic        mem_write;
        logic        mem_read;
        logic        reg_write;
    } ex_mem_t;

    // MEM to WB signal group
    typedef struct packed {
        logic [31:0] alu_result;  // ALU out
        logic [31:0] mem_rdata;   // D_RAM --> RF
        logic [4:0]  rd;          // MEM --> RF
        
        // control signal
        logic        [1:0]result_src;      
        logic        reg_write; 
    } mem_wb_t;

endpackage
