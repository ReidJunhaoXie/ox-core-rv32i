
package core_pkg;

    // local parameter ====================================================

    localparam int REG_ADDR_WIDTH = 5;
    localparam int IRAM_ADDR_WIDTH = 12;
    localparam int DRAM_ADDR_WIDTH = 12;

    // JP out 
    typedef enum logic [1:0] {
        JP_ADD4 = 2'b00 ,
        JP_ADDI = 2'b01 ,
        JP_ALU  = 2'b10 
    } jp_t;

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
        IMM_B   = 3'b011,
        IMM_U   = 3'b100, 
        IMM_J   = 3'b101
    } imme_src_t;

    // RF Source
    typedef enum logic [1:0] { 
        RD_DM   = 2'b00,
        RD_ALU  = 2'b01,
        RD_PC   = 2'b10
    } rf_rd_src_t;

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


    // ID to EX signal group
    typedef struct packed {

        // control signal
        jp_t            jp ;
        logic           branch ;
        logic           rf_wen ;
        logic           dm_wen ;
        rf_rd_src_t     rf_rd_src ;
        alub_src_t      alub_src ;
        logic [3:0]     alu_ctrl ;

    } id_ex_t;



endpackage
