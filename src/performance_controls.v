// Two milliseconds at 50 MHz, input already synchronized by top.
module button_stable #(parameter integer CYCLES=100000)(
 input wire clk,rst_n,pressed_in,output reg pressed);
 reg [31:0] count;
 always @(posedge clk) begin
  if(!rst_n) begin pressed<=0;count<=0;end
  else if(pressed_in==pressed) count<=0;
  else if(count>=CYCLES-1) begin pressed<=pressed_in;count<=0;end
  else count<=count+1'b1;
 end
endmodule

module performance_controls #(parameter integer CHORD_SAMPLES=24000,REPEAT_SAMPLES=4800)(
 input wire clk,rst_n,sample_en,key_down,key_up,
 output reg [2:0] mode,
 output reg [4:0] volume_level,
 output reg [1:0] timbre,env_preset,
 output reg [2:0] test_slot,
 output reg test_pitch_hi,
 output wire bend_down,bend_up,
 output wire [3:0] test_mask);
 reg [14:0] chord_count;
 reg [12:0] repeat_count;
 reg chord_latched;
 reg [1:0] previous;
 wire both=key_down && key_up;
 wire any_key=key_down || key_up;
 wire [1:0] current={key_up,key_down};
 assign bend_down=(mode==0) && !chord_latched && key_down && !key_up;
 assign bend_up=(mode==0) && !chord_latched && key_up && !key_down;
 assign test_mask=(test_slot==0)?4'b1111:(test_slot==1)?4'b1110:
                  (test_slot==2)?4'b1101:(test_slot==3)?4'b1011:4'b0111;
 always @(posedge clk) begin
  if(!rst_n) begin
   mode<=0;volume_level<=16;timbre<=0;env_preset<=0;test_slot<=0;test_pitch_hi<=0;
   chord_count<=0;repeat_count<=0;chord_latched<=0;previous<=0;
  end else if(sample_en) begin
   previous<=current;
   if(!any_key) begin chord_count<=0;repeat_count<=0;chord_latched<=0;end
   else if(chord_latched) begin chord_count<=0;repeat_count<=0;end
   else if(both) begin
    repeat_count<=0;
    if(chord_count>=CHORD_SAMPLES-1) begin
     mode<=(mode==4)?0:mode+1'b1;
     chord_latched<=1;chord_count<=0;
    end else chord_count<=chord_count+1'b1;
   end else begin
    chord_count<=0;
    if(current!=previous || repeat_count>=REPEAT_SAMPLES-1) begin
     repeat_count<=0;
     case(mode)
      1: if(key_down && volume_level>0) volume_level<=volume_level-1'b1;
         else if(key_up && volume_level<16) volume_level<=volume_level+1'b1;
      2: timbre<=key_down?timbre-1'b1:timbre+1'b1;
      3: env_preset<=key_down?env_preset-1'b1:env_preset+1'b1;
      4: if(key_down) test_slot<=(test_slot==4)?0:test_slot+1'b1;
         else test_pitch_hi<=~test_pitch_hi;
     endcase
    end else repeat_count<=repeat_count+1'b1;
   end
  end
 end
endmodule

module volume_smooth(input wire clk,rst_n,sample_en,input wire [4:0] level,
 output reg [15:0] gain_q15);
 wire [15:0] target={level,11'b0};
 always @(posedge clk) begin
  if(!rst_n) gain_q15<=16'd32768;
  else if(sample_en) begin
   if(gain_q15<target) gain_q15<=(target-gain_q15<=128)?target:gain_q15+16'd128;
   else if(gain_q15>target) gain_q15<=(gain_q15-target<=128)?target:gain_q15-16'd128;
  end
 end
endmodule
