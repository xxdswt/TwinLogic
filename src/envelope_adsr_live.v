module envelope_adsr_live (
 input wire clk,rst_n,sample_en,note_on,
 input wire [1:0] env_preset,
 output reg [15:0] envelope,output wire idle);
 localparam [2:0] IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
 reg [2:0] state;
 reg [15:0] attack_step,decay_step,release_step,sustain_level;
 wire [16:0] attack_next={1'b0,envelope}+{1'b0,attack_step};
 wire [16:0] decay_threshold={1'b0,sustain_level}+{1'b0,decay_step};
 assign idle=(state==IDLE);
 always @* begin
  case(env_preset)
   1:begin attack_step=512;decay_step=128;release_step=32;sustain_level=8192;end
   2:begin attack_step=1024;decay_step=1024;release_step=128;sustain_level=65535;end
   3:begin attack_step=16;decay_step=16;release_step=8;sustain_level=49152;end
   default:begin attack_step=64;decay_step=32;release_step=4;sustain_level=39321;end
  endcase
 end
 always @(posedge clk) begin
  if(!rst_n) begin envelope<=0;state<=IDLE;end
  else if(sample_en) case(state)
   IDLE:begin envelope<=0;if(note_on) state<=ATTACK;end
   ATTACK:if(!note_on) state<=RELEASE;
          else if(attack_next>=65535) begin envelope<=65535;state<=DECAY;end
          else envelope<=attack_next[15:0];
   DECAY:if(!note_on) state<=RELEASE;
         else if({1'b0,envelope}<=decay_threshold) begin envelope<=sustain_level;state<=SUSTAIN;end
         else envelope<=envelope-decay_step;
   SUSTAIN:begin envelope<=sustain_level;if(!note_on) state<=RELEASE;end
   RELEASE:if(note_on) state<=ATTACK;
           else if(envelope<=release_step) begin envelope<=0;state<=IDLE;end
           else envelope<=envelope-release_step;
   default:begin envelope<=0;state<=IDLE;end
  endcase
 end
endmodule
