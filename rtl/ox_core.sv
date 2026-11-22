module ox_core 
    import core_pkg::*;
(
    input           clk,
    input           reset_n,

    input   [31:0]  instr_im ,      // from IM
    input   [31:0]  dm_rdata_raw ,  // from DM
    
    output  [31:0]  pc_im ,         // to IM
    output  [31:0]  dm_addr ,
    output          dm_wen ,
    output  [31:0]  dm_wdata ,
    output  [3:0]   dm_byteen
);
    // IFU + IF/ID Reg--------------------------------
    pc_src_t        pc_src ;        // to IF
    logic [31:0]    alu_out_ex ;    // to IF/MEM
    logic [31:0]    pc_adder_out ;  // to IF

    ifu u_ifu(
        .clk(clk),.rst_n(reset_n),
        .pc_src(pc_src),.pc_add_jalr(alu_out_ex),.pc_add_jmp(pc_adder_out),
        .pc(pc_im)
    ) ;
    
    logic [31:0]    pc_if_id ;
    logic [31:0]    instr_if_id ;
    always_ff @( posedge clk ) begin : if_id_r
        if(!reset_n) begin
            pc_if_id       <= '0 ;
            instr_if_id    <= '0 ; 
        end
        else begin
            pc_if_id       <= pc_im ;
            instr_if_id    <= instr_im ; 
        end
    end

    // IDU + RF + ID/EX Reg----------------------------------
    logic [4:0]     rf_raddr1 ;     // to RF in ID phase
    logic [4:0]     rf_raddr2 ;     // to RF in ID phase
    logic [4:0]     rf_waddr_id ;   // to RF in WB phase

    logic [31:0]    rf_rdata1 ;     // from RF in ID phase
    logic [31:0]    rf_rdata2 ;     // from RF in ID phase

    logic [31:0]    imme_ext_id ;   // to pip register
    id_ex_t         id_ex_d ;       // to pip register
    id_ex_t         id_ex_q ;
    idu u_idu(
        .instruction(instr_if_id),
        .id_ex(id_ex_d),
        .rf_raddr1(rf_raddr1),.rf_raddr2(rf_raddr2),.rf_waddr(rf_waddr_id),
        .imme_ext(imme_ext_id)
    ) ;
    mem_wb_t        mem_wb_q ; 
    logic [4:0]     rf_waddr_mem_wb ;
    logic [31:0]    rf_wdata_wb ;
    reg_file u_rf(
        .clk(clk),
        .raddr1(rf_raddr1),.raddr2(rf_raddr2),.waddr(rf_waddr_mem_wb),
        .rdata1(rf_rdata1),.rdata2(rf_rdata2),.wdata(rf_wdata_wb),
        .we(mem_wb_q.rf_wen)
    ) ;
    logic [31:0]    rf_rdata1_id_ex ;  
    logic [31:0]    rf_rdata2_id_ex ; 
    logic [31:0]    imme_ext_id_ex ;
    logic [4:0]     rf_waddr_id_ex ;
    logic [31:0]    pc_id_ex ;
    always_ff @( posedge clk ) begin : id_ex_r_ctrl
        if(!reset_n)    id_ex_q <= '0 ;
        else            id_ex_q <= id_ex_d ;
    end
    always_ff @( posedge clk ) begin : id_ex_r_data
        rf_rdata1_id_ex <= rf_rdata1 ;
        rf_rdata2_id_ex <= rf_rdata2 ;
        imme_ext_id_ex  <= imme_ext_id ;
        rf_waddr_id_ex  <= rf_waddr_id ;
        pc_id_ex        <= pc_if_id ;
    end

    // EXU + EX/MEM Reg----------------------------------
    //logic [1:0]     pc_src ;        // to IF      declaration in IF
    //logic [31:0]    alu_out_ex ;    // to IF/MEM  declaration in IF
    //logic [31:0]    pc_adder_out ;  // to IF      declaration in IF
    logic [31:0]    pc_add4_ex ;      // to MEM
    exu u_exu(
        .rf_rdata1(rf_rdata1_id_ex),.rf_rdata2(rf_rdata2_id_ex),.imme_ext(imme_ext_id_ex),.pc_in(pc_id_ex),
        .funct3(id_ex_q.funct3),.alu_ctrl(id_ex_q.alu_ctrl),.jp(id_ex_q.jp),.branch(id_ex_q.branch),.alub_src(id_ex_q.alub_src),.alua_src(id_ex_q.alua_src),
        .pc_src(pc_src),.alu_out(alu_out_ex),.pc_adder_out(pc_adder_out),.pc_add4(pc_add4_ex)
    ) ;
    ex_mem_t        ex_mem_q ;
    logic [31:0]    alu_out_ex_mem ;  // declaration in IF
    logic [31:0]    pc_add4_ex_mem ;  // declaration in IF
    logic [31:0]    rf_rdata2_ex_mem ;
    logic [4:0]     rf_waddr_ex_mem ;
    always_ff @( posedge clk ) begin : ex_mem_r_ctrl
        if(!reset_n)    ex_mem_q <= '0 ;
        else begin
                        ex_mem_q.rf_wen     <= id_ex_q.rf_wen ;
                        ex_mem_q.dm_wen     <= id_ex_q.dm_wen ;
                        ex_mem_q.rf_rd_src  <= id_ex_q.rf_rd_src ;
                        ex_mem_q.funct3     <= id_ex_q.funct3 ;
        end
    end
    always_ff @( posedge clk ) begin : ex_mem_r_data
        alu_out_ex_mem      <= alu_out_ex ;
        pc_add4_ex_mem      <= pc_add4_ex ;
        rf_rdata2_ex_mem    <= rf_rdata2_id_ex ;
        rf_waddr_ex_mem     <= rf_waddr_id_ex ;
    end

    // LSU + MEM/WB Reg----------------------------------
    logic [31:0]    dm_wdata_mem ;  // to DM
    logic [31:0]    dm_rdata_mem ;  // to WB
    logic [3:0]     byteen ;
    assign  dm_wen      = ex_mem_q.dm_wen ; // to DM
    assign  dm_wdata    = dm_wdata_mem ;    // to DM
    assign  dm_byteen   = byteen ;          // to DM
    assign  dm_addr     = { alu_out_ex_mem[31:2],2'b00 } ; // to DM
    lsu u_lsu(
        .addr(alu_out_ex_mem[1:0]),.rf_rdata2(rf_rdata2_ex_mem),.dm_rdata_i(dm_rdata_raw),
        .funct3(ex_mem_q.funct3),.dm_wen(ex_mem_q.dm_wen),
        .dm_wdata_o(dm_wdata_mem),.dm_rdata_o(dm_rdata_mem),.byteen(byteen)
    ) ;
    // mem_wb_t        mem_wb_q ;           declaration in ID
    logic [31:0]    dm_rdata_mem_wb ;
    logic [31:0]    alu_out_mem_wb ;
    // logic [4:0]     rf_waddr_mem_wb ;    declaration in ID
    logic [31:0]    pc_add4_mem_wb ;
    always_ff @( posedge clk ) begin : mem_wb_r_ctrl
        if(!reset_n)    mem_wb_q <= '0 ;
        else begin
                        mem_wb_q.rf_wen     <= ex_mem_q.rf_wen ;
                        mem_wb_q.rf_rd_src  <= ex_mem_q.rf_rd_src ;
        end 
    end
    always_ff @( posedge clk ) begin : mem_wb_r_data
        dm_rdata_mem_wb <= dm_rdata_mem ;
        alu_out_mem_wb  <= alu_out_ex_mem ;
        pc_add4_mem_wb  <= pc_add4_ex_mem ;
        rf_waddr_mem_wb <= rf_waddr_ex_mem ;
    end

    //  WBU  ----------------------------------
    // logic [31:0]    rf_wdata_wb ;   // to RF , declaration in ID
    wbu u_wbu(
        .rf_rd_src(mem_wb_q.rf_rd_src),
        .dm_rdata(dm_rdata_mem_wb),
        .alu_out(alu_out_mem_wb),
        .pc_add4(pc_add4_mem_wb),
        .rf_wdata(rf_wdata_wb) // back to RF
    ) ;
    

endmodule
