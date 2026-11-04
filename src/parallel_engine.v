// 32 physically instantiated phase accumulators, ADSRs and amplitude paths.
// Normal mode uses voices0..3; TEST enables independently adjustable voices0..31.
// Five registered adder levels prevent a 32-input combinational carry chain.
`default_nettype none
module parallel_engine(input wire clk,rst_n,sample_en,test_mode,test_all,
 input wire [20:0] pitch_ratio,input wire [1:0] env_preset,
 input wire [223:0] notes,input wire [31:0] gates,input wire [63:0] waves,
 output wire signed [15:0] sample_out,output wire [31:0] voice_idle,
 output wire [1023:0] phase_steps_debug);
 reg [20:0] ratio_registered;
 always @(posedge clk)begin
  if(!rst_n)ratio_registered<=21'd1048576;else ratio_registered<=pitch_ratio;
 end
 wire signed [15:0] samples[0:31];
 genvar v;
 generate for(v=0;v<32;v=v+1) begin:g_voice
  parallel_voice u_voice(.clk(clk),.rst_n(rst_n),.sample_en(sample_en),.pitch_ratio(ratio_registered),
  .env_preset(env_preset),.note(notes[v*7+:7]),.note_on(gates[v]),.wave_sel(waves[v*2+:2]),
  .sample_out(samples[v]),.voice_idle(voice_idle[v]),.phase_step_debug(phase_steps_debug[v*32+:32]));
 end endgenerate
 reg signed [16:0] level1[0:15];
 reg signed [17:0] level2[0:7];
 reg signed [18:0] level3[0:3];
 reg signed [19:0] level4[0:1];
 reg signed [20:0] level5;
 integer i;
 always @(posedge clk) begin
  if(!rst_n) begin
   for(i=0;i<16;i=i+1)level1[i]<=0;
   for(i=0;i<8;i=i+1)level2[i]<=0;
   for(i=0;i<4;i=i+1)level3[i]<=0;
   for(i=0;i<2;i=i+1)level4[i]<=0;
   level5<=0;
  end else begin
   for(i=0;i<16;i=i+1)level1[i]<=$signed({samples[2*i][15],samples[2*i]})+$signed({samples[2*i+1][15],samples[2*i+1]});
   for(i=0;i<8;i=i+1)level2[i]<=$signed({level1[2*i][16],level1[2*i]})+$signed({level1[2*i+1][16],level1[2*i+1]});
   for(i=0;i<4;i=i+1)level3[i]<=$signed({level2[2*i][17],level2[2*i]})+$signed({level2[2*i+1][17],level2[2*i+1]});
   for(i=0;i<2;i=i+1)level4[i]<=$signed({level3[2*i][18],level3[2*i]})+$signed({level3[2*i+1][18],level3[2*i+1]});
   level5<=$signed({level4[0][19],level4[0]})+$signed({level4[1][19],level4[1]});
  end
 end
 // Normal path preserves the accepted four-voice /4 level; 32-tone test uses /32.
 wire signed [15:0] solo_sample=(level5>21'sd32767)?16'sd32767:
      (level5< -21'sd32768)?-16'sd32768:level5[15:0];
 assign sample_out=test_mode?(test_all?level5[20:5]:solo_sample):level5[17:2];
endmodule
`default_nettype wire
