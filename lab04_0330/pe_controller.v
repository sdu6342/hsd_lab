`timescale 1ns / 1ps

module pe_controller #(parameter DATA_BW = 32, parameter ADDR_BW = 5)
(
    //control signals
    input start,
    input clk,
    input reset,
    output done,
    
    //data/address pins
    output      [ADDR_BW - 1 : 0] rdaddr,
    input       [DATA_BW - 1 : 0] rddata,
    output      [DATA_BW - 1 : 0] wrdata
);

//controller memory
(* ram_style = "block" *) reg [DATA_BW - 1:0] mem[0:15];

//controller PE
//You may define your own reg/wire to run it
reg [31:0] addr; assign rdaddr = addr;
reg we, valid;
reg [2:0]count_5;
wire dvalid;
wire [31:0] dout;


my_pe #(ADDR_BW - 1) PE
(
    .aclk(clk),
    .areset(reset),

    .ain(mem[addr]),
    .din(rddata),
    .addr(addr),

    .we(we),
    .valid(valid),
    .dvalid(dvalid),

    .dout(dout)
);

    //Write your logic here.
    //You are free to use given logic or not.

//state registers & constants
reg [1 : 0] present_state, next_state;
localparam IDLE = 2'd0;
localparam LOAD = 2'd1;
localparam CALC = 2'd2;
localparam DONE = 2'd3;


assign wrdata = done? dout : 0;
assign done = present_state == DONE? 1 : 0; 

//determine and update state // reverse reset
always @(posedge clk or negedge reset)
    present_state <= reset ? next_state : IDLE;
  
always @(*)
    case(present_state)
        IDLE : next_state = start? LOAD : IDLE;
        LOAD : next_state = (addr == 32)? CALC : LOAD;
        CALC : next_state = (addr == 16)? DONE : CALC;//FILL IN HERE
        DONE : next_state = (count_5 == 4)? IDLE : DONE;//FILL IN HERE
    endcase
    
//main
integer i;
reg loaded;

always @(posedge clk) begin
    if( present_state == DONE)
        count_5 <= count_5 + 1;
    else 
        count_5 <= 0; 
end

always @(posedge clk) begin

    if(!reset) begin
        for(i=0; i< 16; i=i+1) begin
            mem[i] = {DATA_BW{'b0}};
        end 
        addr <= 0;
        we <= 0; 
        valid <= 0;
        count_5 <= 0;
    end
    else begin
        case(present_state)
            IDLE :
                begin
                    addr <= 0;
                    if (start) begin
                        $display("Loading din_mem[%d] at rddata", addr);
                        we <= 1;
                        loaded <= 1;
                    end
                end
            LOAD :
                begin
                    if (addr < 16) begin
                        if (loaded) begin
                            $display("rddata was written at peram[%d]", addr);
                            we <= 0;
                            addr <= addr + 1;
                            loaded <= 0;
                        end
                        else begin
                            $display("Loading din_mem[%d] at rddata", addr);
                            we <= 1;
                            loaded <= 1;
                        end
                    end
                    else if (addr < 32) begin
                        if (loaded) begin
                            $display("rddata was written at mem[%d]", addr - 16);
                            mem[addr - 16] <= rddata;
                            addr <= addr + 1;
                            loaded <= 0;
                        end
                        else begin
                            $display("Loading din_mem[%d] at rddata", addr);
                            loaded <= 1;
                        end
                    end
                    else begin
                        addr <= 0;
                        valid <= 1;
                        //You may have to modify here too
                    end 
                end
            CALC :
                begin
                  if( addr < 16 && dvalid) begin
                        addr <= addr + 1;
                        valid <= 1;
                    end
                    else begin
                        addr <= addr;
                    end
                end
            DONE :
                begin
                  
                end
        endcase
    end
end

always @(posedge clk) begin
    if(valid)
       valid <= 0;
end


endmodule