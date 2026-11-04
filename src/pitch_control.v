// +/-2 semitone endpoint ratios in unsigned Q20; ramps on sample_en.
module pitch_ratio_ctrl #(parameter integer RAMP_STEP=1024)(
 input wire clk,rst_n,sample_en,bend_down,bend_up,
 output reg [20:0] pitch_ratio);
 localparam [20:0] CENTER=21'd1048576;
 localparam [20:0] DOWN=21'd934175;
 localparam [20:0] UP=21'd1176987;
 localparam integer STEP=(RAMP_STEP<1)?1:RAMP_STEP;
 wire [20:0] target=(bend_down && !bend_up)?DOWN:
                       (bend_up && !bend_down)?UP:CENTER;
 always @(posedge clk) begin
  if(!rst_n) pitch_ratio<=CENTER;
  else if(sample_en) begin
   if(pitch_ratio<target) begin
    if(target-pitch_ratio<=STEP) pitch_ratio<=target;
    else pitch_ratio<=pitch_ratio+STEP;
   end else if(pitch_ratio>target) begin
    if(pitch_ratio-target<=STEP) pitch_ratio<=target;
    else pitch_ratio<=pitch_ratio-STEP;
   end
  end
 end
endmodule

module phase_scale_q20(
 input wire clk,rst_n,
 input wire [31:0] base_phase_inc,
 input wire [20:0] pitch_ratio,
 output wire [31:0] phase_inc);
 reg [52:0] product;
 wire [52:0] rounded=product+53'd524288;
 always @(posedge clk) begin
  if(!rst_n) product<=0;
  else product<=base_phase_inc*pitch_ratio;
 end
 assign phase_inc=rounded[51:20];
endmodule
