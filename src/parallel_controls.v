// Board controls: singles act immediately; a later chord rolls back that
// gesture's parameter edits. Once BOTH keys have been observed, the complete
// gesture is consumed until BOTH are released, even for a cancelled short chord.
module parallel_controls #(parameter integer CHORD_SAMPLES=24000,REPEAT_SAMPLES=4800)(
 input wire clk,rst_n,sample_en,key_down,key_up,
 output reg [2:0] mode,
 output reg [4:0] volume_level,
 output reg [1:0] timbre,env_preset,
 output reg [4:0] test_focus,
 output reg [31:0] test_mute,
 output wire bend_down,bend_up,
 output wire [31:0] test_mask);
 reg [14:0] chord_count;
 reg [12:0] repeat_count;
 reg chord_seen,chord_latched,chord_cancelled,snapshot_valid;
 reg [1:0] previous;
 reg [4:0] saved_volume,saved_focus;
 reg [1:0] saved_timbre,saved_env;
 reg [31:0] saved_mute;
 wire both=key_down && key_up;
 wire any_key=key_down || key_up;
 wire [1:0] current={key_up,key_down};
 // BEND has no added recognition delay. A consumed chord cannot become a
 // bend when one of its two keys is released before the other.
 assign bend_down=(mode==0) && !chord_seen && key_down && !key_up;
 assign bend_up=(mode==0) && !chord_seen && key_up && !key_down;
 assign test_mask=~test_mute;
 always @(posedge clk) begin
  if(!rst_n) begin
   mode<=0;volume_level<=16;timbre<=0;env_preset<=0;test_focus<=0;test_mute<=0;
   chord_count<=0;repeat_count<=0;previous<=0;
   chord_seen<=0;chord_latched<=0;chord_cancelled<=0;snapshot_valid<=0;
   saved_volume<=16;saved_timbre<=0;saved_env<=0;saved_focus<=0;saved_mute<=0;
  end else if(sample_en) begin
   previous<=current;
   if(!any_key) begin
    chord_count<=0;repeat_count<=0;
    chord_seen<=0;chord_latched<=0;chord_cancelled<=0;snapshot_valid<=0;
   end else if(both) begin
    repeat_count<=0;
    if(!chord_seen) begin
     chord_seen<=1;
     if(snapshot_valid) begin
      volume_level<=saved_volume;timbre<=saved_timbre;env_preset<=saved_env;
      test_focus<=saved_focus;test_mute<=saved_mute;
     end
     if(CHORD_SAMPLES<=1) begin
      mode<=(mode==4)?3'd0:mode+3'd1;
      if(mode==3)begin test_focus<=0;test_mute<=0;end
      chord_latched<=1;chord_count<=0;
     end else chord_count<=1;
    end else if(!chord_latched && !chord_cancelled) begin
     if(chord_count>=CHORD_SAMPLES-1) begin
      mode<=(mode==4)?3'd0:mode+3'd1;
      // Each TEST entry is deterministic: solo FOCUS01/A4, no stored mutes.
      if(mode==3)begin test_focus<=0;test_mute<=0;end
      chord_latched<=1;chord_count<=0;
     end else chord_count<=chord_count+1'b1;
    end
   end else if(chord_seen) begin
    // A partial release cancels an unfinished chord. Re-pressing the second
    // key cannot resume it; release BOTH before beginning another gesture.
    chord_count<=0;repeat_count<=0;
    if(!chord_latched)chord_cancelled<=1;
   end else begin
    chord_count<=0;
    if(!snapshot_valid) begin
     saved_volume<=volume_level;saved_timbre<=timbre;saved_env<=env_preset;
     saved_focus<=test_focus;saved_mute<=test_mute;snapshot_valid<=1;
    end
    if(current!=previous || (mode==1 && repeat_count>=REPEAT_SAMPLES-1)) begin
     repeat_count<=0;
     case(mode)
      1:if(key_down && volume_level>0)volume_level<=volume_level-1'b1;
        else if(key_up && volume_level<16)volume_level<=volume_level+1'b1;
      // Presets and test actions advance once per press, irrespective of hold.
      2:if(current!=previous)timbre<=key_down?timbre-2'd1:timbre+2'd1;
      3:if(current!=previous)env_preset<=key_down?env_preset-2'd1:env_preset+2'd1;
      4:if(current!=previous)begin
         if(key_down)test_focus<=test_focus+1'b1;
         else test_mute[test_focus]<=~test_mute[test_focus];
        end
     endcase
    end else if(mode==1)repeat_count<=repeat_count+1'b1;
    else repeat_count<=0;
   end
  end
 end
endmodule
