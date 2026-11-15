module lsu (
    input   logic   [1:0]   addr ,      // alu_out[1:0]
    input   logic   [31:0]  rf_rdata2 , // raw data from RF
    input   logic   [31:0]  dm_rdata_i ,// raw data from DM
    
    // control signal
    input   logic   [2:0]   funct3 ,
    input   logic           dm_wen ,

    output  logic   [31:0]  dm_wdata_o ,// Data to DM
    output  logic   [31:0]  dm_rdata_o ,// Data to RF 
    output  logic   [3:0]   byteen      // to DM
    // output  logic           dm_wen_o

);
    // feat: rf_rdata adjust to dm_wdata / gen byteen
    always_comb begin : store_alignment
        byteen = 4'b0000 ;
        dm_wdata_o = rf_rdata2 ;
        casez ({dm_wen,funct3[1:0]})
            3'b0??: byteen = 4'd0 ;
            3'b100: begin
                byteen = 4'b0001 << addr ;
                dm_wdata_o = { 4{rf_rdata2[7:0]} }; 
            end  
            3'b101: begin
                byteen = 4'b0011 << {addr[1],1'b0};
                dm_wdata_o = { 2{rf_rdata2[15:0]} };
            end
            3'b110: begin
                byteen = 4'b1111 ;
                dm_wdata_o = rf_rdata2 ;
            end
            default: begin
                byteen = 4'b0000 ;
                dm_wdata_o = rf_rdata2 ;
            end 
        endcase
    end
    
    logic   [5:0]   width ;
    logic   [4:0]   base ;
    logic           fill_bit ;
    assign width    = 8 << funct3[1:0] ;
    assign base     = ((funct3[1:0]==0)? {addr[1:0],3'b000} : (funct3[1:0]==1)? {addr[1],4'b0000} : 5'd0) ;
    assign fill_bit = (funct3[2])? 1'b0 : dm_rdata_i[base+width-1] ; // sign bit  
    always_comb begin : load_alignment
        case (funct3[1:0])
            2'b00: dm_rdata_o = { {24{fill_bit}},dm_rdata_i[base +: 8] } ;
            2'b01: dm_rdata_o = { {16{fill_bit}},dm_rdata_i[base +: 16] } ;
            2'b10: dm_rdata_o = dm_rdata_i ;
            default: dm_rdata_o = dm_rdata_i ;
        endcase
    end


endmodule