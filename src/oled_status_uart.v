module oled_performance_status #(parameter integer REPORT_CYCLES=5000000)(
 input wire clk,rst_n,input wire [2:0] mode,input wire [4:0] volume_level,
 input wire [1:0] timbre,env_preset,input wire [3:0] test_mask,input wire test_pitch_hi,
 input wire oled_ready,input wire [1:0] oled_error,input wire [6:0] oled_address,
 output wire tx);
 reg [31:0] period;
 reg [1:0] state;
 reg [5:0] index;
 reg r;reg [1:0] err;reg [6:0] addr;
 reg start;
 reg [7:0] data;
 reg [2:0] m;
 reg [4:0] v;
 reg [1:0] t,e;
 reg [3:0] x;
 reg h;
 wire busy;
 function [7:0] hexchar;input [3:0] n;begin hexchar=n<10?8'd48+n:8'd55+n;end endfunction
 status_uart_tx u_tx(.clk(clk),.rst_n(rst_n),.start(start),.data(data),.tx(tx),.busy(busy));
 always @(posedge clk) begin
  if(!rst_n) begin period<=0;state<=0;index<=0;start<=0;data<=0;m<=0;v<=16;t<=0;e<=0;x<=15;h<=0;r<=0;err<=0;addr<=0;end
  else begin
   start<=0;
   case(state)
    0:if(period>=REPORT_CYCLES-1) begin period<=0;m<=mode;v<=volume_level;t<=timbre;e<=env_preset;x<=test_mask;h<=test_pitch_hi;r<=oled_ready;err<=oled_error;addr<=oled_address;index<=0;state<=1;end
      else period<=period+1'b1;
    1:begin
     case(index)
      0:data<=8'h4d;1:data<=8'd48+m;2:data<=8'h20;
      3:data<=8'h56;4:data<=8'd48+(v>=10);5:data<=8'd48+((v>=10)?v-5'd10:v);6:data<=8'h20;
      7:data<=8'h54;8:data<=8'd48+t;9:data<=8'h20;
      10:data<=8'h45;11:data<=8'd48+e;12:data<=8'h20;
      13:data<=8'h58;14:data<=hexchar(x);15:data<=8'h20;
      16:data<=8'h48;17:data<=8'd48+h;18:data<=13;19:data<=10;
      20:data<=8'h4f;21:data<=8'h4c;22:data<=8'h45;23:data<=8'h44;24:data<=32;
      25:data<=8'h52;26:data<=8'd48+r;27:data<=32;
      28:data<=8'h41;29:data<=hexchar({1'b0,addr[6:4]});30:data<=hexchar(addr[3:0]);31:data<=32;
      32:data<=8'h45;33:data<=8'd48+err;34:data<=13;35:data<=10;
     endcase
     start<=1;state<=2;
    end
    2:if(busy) state<=3;
    3:if(!busy) begin if(index==35) state<=0;else begin index<=index+1'b1;state<=1;end end
   endcase
  end
 end
endmodule
