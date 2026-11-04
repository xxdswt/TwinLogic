// SSD1306-compatible 128x64 page renderer. Controller ID is NOT probed.
// Probe 7-bit addresses 3C then 3D. Any NACK aborts, releases bus and retries.
// Each pixel byte uses address/control/data transaction; ~3Hz full refresh.
// OLED and I2C failures never gate, reset or stall the audio engine.
`default_nettype none
module oled_status #(
 parameter integer I2C_QUARTER_CYCLES=125,
 parameter integer I2C_TIMEOUT_CYCLES=50000,
 parameter integer POWERUP_CYCLES=5000000,
 parameter integer RETRY_CYCLES=25000000,
 parameter integer FRAME_PAUSE_CYCLES=1000000,
 parameter integer COLUMN_OFFSET=0
)(input wire clk,rst_n,input wire [2:0] mode,
 input wire [4:0] volume_level,input wire [1:0] timbre,env_preset,
 input wire [15:0] key_state,input wire [3:0] voice_idle,test_mask,
 input wire test_pitch_hi,inout wire scl,sda,
 output reg ready,output reg [6:0] address,output reg [1:0] error,
 output reg [15:0] frames);
 localparam BOOT=0,SEND=1,WAIT_BYTE=2,ADVANCE=3,RETRY=4,SNAPSHOT=5,PAUSE=6;
 localparam PROBE=0,INIT=1,PAGE=2,PIXEL=3,DISPLAY_ON=4;
 reg [2:0] state,kind;
 reg [31:0] delay_count;
 reg [1:0] byte_index;
 reg [4:0] init_index;
 reg [1:0] page_command;
 reg [2:0] page;
 reg [6:0] column;
 reg request,first,last;
 reg [7:0] data;
 wire bus_busy,done,nack,bus_timeout;
 reg [2:0] m;
 reg [4:0] v;
 reg [1:0] t,e;
 reg [15:0] k;
 reg [3:0] idle,x;
 reg h;
 reg [127:0] text_line;
 reg [7:0] character;
 wire [7:0] pixels;
 wire [2:0] active_voices={2'b0,!idle[0]}+{2'b0,!idle[1]}+{2'b0,!idle[2]}+{2'b0,!idle[3]};
 function [7:0] hexchar;input [3:0] n;begin hexchar=(n<10)?8'd48+n:8'd55+n;end endfunction
 function [7:0] init_byte;input [4:0] n;begin
  case(n)
   0:init_byte=8'hae;1:init_byte=8'hd5;2:init_byte=8'h80;
   3:init_byte=8'ha8;4:init_byte=8'h3f;5:init_byte=8'hd3;6:init_byte=0;
   7:init_byte=8'h40;8:init_byte=8'h8d;9:init_byte=8'h14;
   10:init_byte=8'h20;11:init_byte=8'h02;12:init_byte=8'ha1;13:init_byte=8'hc8;
   14:init_byte=8'hda;15:init_byte=8'h12;16:init_byte=8'h81;17:init_byte=8'h7f;
   18:init_byte=8'hd9;19:init_byte=8'hf1;20:init_byte=8'hdb;21:init_byte=8'h20;
   22:init_byte=8'ha4;23:init_byte=8'ha6;default:init_byte=8'h2e;
  endcase
 end endfunction
 reg [7:0] payload;
 always @* begin
  case(page)
   0:text_line="TWINLOGIC M3.4  ";
   1:case(m)
    0:text_line="MODE: BEND      ";1:text_line="MODE: VOLUME    ";2:text_line="MODE: TIMBRE    ";
    3:text_line="MODE: ENVELOPE  ";default:text_line="MODE: TEST      ";endcase
   2:text_line="VOL: 00/16      ";
   3:case(t)
    0:text_line="TONE: MIXED     ";1:text_line="TONE: SINE      ";
    2:text_line="TONE: TRIANGLE  ";default:text_line="TONE: SAW       ";endcase
   4:case(e)
    0:text_line="ENV: CLASSIC    ";1:text_line="ENV: PLUCK      ";
    2:text_line="ENV: ORGAN      ";default:text_line="ENV: PAD        ";endcase
   5:text_line="KEYS:0000 V:0   ";
   6:if(m==4) text_line="TEST:1234 P:D5  ";else text_line="KEY0- KEY2+     ";
   default:text_line="I2C:3C FPGA 48K ";
  endcase
  character=text_line[(15-column[6:3])*8 +: 8];
  if(page==2) case(column[6:3])
   5:character=8'd48+(v>=10);6:character=8'd48+((v>=10)?v-5'd10:v);default:;
  endcase
  if(page==5) case(column[6:3])
   5:character=hexchar(k[15:12]);6:character=hexchar(k[11:8]);
   7:character=hexchar(k[7:4]);8:character=hexchar(k[3:0]);
   12:character=8'd48+active_voices;default:;
  endcase
  if(page==6 && m==4) case(column[6:3])
   5:character=x[0]?8'd49:8'd45;6:character=x[1]?8'd50:8'd45;
   7:character=x[2]?8'd51:8'd45;8:character=x[3]?8'd52:8'd45;
   12:character=h?8'd69:8'd68;default:;
  endcase
  if(page==7 && column[6:3]==5) character=hexchar(address[3:0]);
  case(kind)
   INIT:payload=init_byte(init_index);
   PAGE:case(page_command)
    0:payload=8'hb0+{5'd0,page};
    1:payload={4'b0000,COLUMN_OFFSET[3:0]};
    default:payload={4'b0001,COLUMN_OFFSET[7:4]};
   endcase
   PIXEL:payload=pixels;
   default:payload=8'haf;
  endcase
 end
 oled_font u_font(.character(character),.column(column[2:0]),.pixels(pixels));
 i2c_write_byte #(.QUARTER_CYCLES(I2C_QUARTER_CYCLES),.TIMEOUT_CYCLES(I2C_TIMEOUT_CYCLES)) u_bus(
 .clk(clk),.rst_n(rst_n),.request(request),.data(data),.first(first),.last(last),
 .scl(scl),.sda(sda),.busy(bus_busy),.done(done),.nack(nack),.timeout(bus_timeout));
 always @(posedge clk) begin
  if(!rst_n) begin
   state<=BOOT;kind<=PROBE;delay_count<=0;byte_index<=0;init_index<=0;page_command<=0;
   page<=0;column<=0;request<=0;data<=0;first<=0;last<=0;
   ready<=0;address<=7'h3c;error<=0;frames<=0;
   m<=0;v<=16;t<=0;e<=0;k<=0;idle<=15;x<=15;h<=0;
  end else begin
   request<=0;
   case(state)
    BOOT:if(delay_count>=POWERUP_CYCLES-1) begin delay_count<=0;state<=SEND;end
         else delay_count<=delay_count+1'b1;
    SEND:if(!bus_busy) begin
     first<=(byte_index==0);last<=(kind==PROBE || byte_index==2);
     case(byte_index)
      0:data<={address,1'b0};1:data<=(kind==PIXEL)?8'h40:8'h00;default:data<=payload;
     endcase
     request<=1;state<=WAIT_BYTE;
    end
    WAIT_BYTE:if(done) begin
     if(nack || bus_timeout) begin
      ready<=0;error<=bus_timeout?2'd2:2'd1;byte_index<=0;
      if(kind==PROBE && address==7'h3c) begin address<=7'h3d;state<=SEND;end
      else begin state<=RETRY;delay_count<=0;end
     end else if(kind!=PROBE && byte_index!=2) begin byte_index<=byte_index+1'b1;state<=SEND;end
     else begin byte_index<=0;state<=ADVANCE;end
    end
    ADVANCE:case(kind)
     PROBE:begin kind<=INIT;init_index<=0;state<=SEND;end
     INIT:if(init_index==24) state<=SNAPSHOT;
          else begin init_index<=init_index+1'b1;state<=SEND;end
     PAGE:if(page_command==2) begin kind<=PIXEL;column<=0;state<=SEND;end
          else begin page_command<=page_command+1'b1;state<=SEND;end
     PIXEL:if(column==127) begin
       if(page==7) begin kind<=DISPLAY_ON;state<=SEND;end
       else begin page<=page+1'b1;page_command<=0;kind<=PAGE;state<=SEND;end
      end else begin column<=column+1'b1;state<=SEND;end
     default:begin ready<=1;error<=0;frames<=frames+1'b1;delay_count<=0;state<=PAUSE;end
    endcase
    SNAPSHOT:begin
     m<=mode;v<=volume_level;t<=timbre;e<=env_preset;k<=key_state;idle<=voice_idle;x<=test_mask;h<=test_pitch_hi;
     page<=0;column<=0;page_command<=0;kind<=PAGE;state<=SEND;
    end
    PAUSE:if(delay_count>=FRAME_PAUSE_CYCLES-1) begin delay_count<=0;state<=SNAPSHOT;end
          else delay_count<=delay_count+1'b1;
    RETRY:if(delay_count>=RETRY_CYCLES-1) begin
       delay_count<=0;kind<=PROBE;address<=7'h3c;byte_index<=0;state<=SEND;
      end else delay_count<=delay_count+1'b1;
    default:state<=BOOT;
   endcase
  end
 end
endmodule
`default_nettype wire
