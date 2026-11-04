// Single-master, open-drain I2C byte engine. No pin is ever driven HIGH.
// QUARTER_CYCLES=125 at 50MHz gives approximately 100kHz SCL.
// Continuation bytes retain SCL LOW while waiting for their request.
`default_nettype none
module i2c_write_byte #(
 parameter integer QUARTER_CYCLES=125,
 parameter integer TIMEOUT_CYCLES=50000
)(input wire clk,rst_n,request,input wire [7:0] data,
 input wire first,last,inout wire scl,sda,
 output wire busy,output reg done,nack,timeout);
 localparam IDLE=0,START_WAIT=1,START_HOLD=2,BIT_SETUP=3,
 BIT_RISE=4,BIT_HOLD=5,BIT_FALL=6,ACK_SETUP=7,ACK_RISE=8,
 ACK_HOLD=9,ACK_FALL=10,STOP_SETUP=11,STOP_RISE=12,STOP_RELEASE=13,STOP_HOLD=14,FINISH=15;
 reg [3:0] state;
 reg scl_low,sda_low,last_byte;
 reg [7:0] shift;
 reg [2:0] bit_index;
 reg [31:0] phase_count,stall_count;
 reg scl_meta,scl_sync,sda_meta,sda_sync;
 assign scl=scl_low?1'b0:1'bz;
 assign sda=sda_low?1'b0:1'bz;
 assign busy=(state!=IDLE);
 wire stalled=((state==BIT_HOLD || state==ACK_HOLD || state==STOP_RELEASE) && !scl_sync)
             || (state==START_WAIT && (!scl_sync || !sda_sync));
 always @(posedge clk) begin
  if(!rst_n) begin scl_meta<=1;scl_sync<=1;sda_meta<=1;sda_sync<=1;end
  else begin scl_meta<=scl;scl_sync<=scl_meta;sda_meta<=sda;sda_sync<=sda_meta;end
 end
 always @(posedge clk) begin
  if(!rst_n) begin
   state<=IDLE;scl_low<=0;sda_low<=0;last_byte<=0;shift<=0;bit_index<=7;
   phase_count<=0;stall_count<=0;done<=0;nack<=0;timeout<=0;
  end else begin
   done<=0;
   if(state==IDLE) begin
    phase_count<=0;stall_count<=0;
    if(request) begin
     shift<=data;bit_index<=7;last_byte<=last;nack<=0;timeout<=0;
     if(first) begin scl_low<=0;sda_low<=0;state<=START_WAIT;end
     else begin scl_low<=1;state<=BIT_SETUP;end
    end
   end else if(stalled) begin
    phase_count<=0;
    if(stall_count>=TIMEOUT_CYCLES-1) begin
     scl_low<=0;sda_low<=0;timeout<=1;state<=FINISH;stall_count<=0;
    end else stall_count<=stall_count+1'b1;
   end else begin
    stall_count<=0;
    if(phase_count>=QUARTER_CYCLES-1) begin
     phase_count<=0;
     case(state)
      START_WAIT:begin sda_low<=1;state<=START_HOLD;end
      START_HOLD:begin scl_low<=1;state<=BIT_SETUP;end
      BIT_SETUP:begin sda_low<=!shift[bit_index];state<=BIT_RISE;end
      BIT_RISE:begin scl_low<=0;state<=BIT_HOLD;end
      BIT_HOLD:state<=BIT_FALL;
      BIT_FALL:begin
       scl_low<=1;
       if(bit_index==0) state<=ACK_SETUP;
       else begin bit_index<=bit_index-1'b1;state<=BIT_SETUP;end
      end
      ACK_SETUP:begin sda_low<=0;state<=ACK_RISE;end
      ACK_RISE:begin scl_low<=0;state<=ACK_HOLD;end
      ACK_HOLD:begin nack<=sda_sync;state<=ACK_FALL;end
      ACK_FALL:begin
       scl_low<=1;
       if(last_byte || nack) state<=STOP_SETUP;
       else state<=FINISH;
      end
      STOP_SETUP:begin sda_low<=1;state<=STOP_RISE;end
      STOP_RISE:begin scl_low<=0;state<=STOP_RELEASE;end
      STOP_RELEASE:begin sda_low<=0;state<=STOP_HOLD;end
      STOP_HOLD:state<=FINISH;
      FINISH:begin done<=1;state<=IDLE;end
      default:begin scl_low<=0;sda_low<=0;state<=IDLE;end
     endcase
    end else phase_count<=phase_count+1'b1;
   end
  end
 end
endmodule
`default_nettype wire
