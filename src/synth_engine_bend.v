// M3.2 engine: four independent voices with shared unsigned Q20 pitch ratio.
module synth_engine_bend (
    input wire clk,
    input wire rst_n,
    input wire sample_en,
    input wire [20:0] pitch_ratio,
    input wire [1:0] env_preset,

    input wire [6:0] note0,
    input wire [6:0] note1,
    input wire [6:0] note2,
    input wire [6:0] note3,

    input wire note_on0,
    input wire note_on1,
    input wire note_on2,
    input wire note_on3,

    input wire [1:0] wave_sel0,
    input wire [1:0] wave_sel1,
    input wire [1:0] wave_sel2,
    input wire [1:0] wave_sel3,

    output wire signed [15:0] sample_out,
    output wire [3:0] voice_idle
);

    wire signed [15:0] voice0_sample;
    wire signed [15:0] voice1_sample;
    wire signed [15:0] voice2_sample;
    wire signed [15:0] voice3_sample;

    synth_voice_bend u_voice0 (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_en  (sample_en),
        .pitch_ratio(pitch_ratio),
        .env_preset(env_preset),
        .note       (note0),
        .note_on    (note_on0),
        .wave_sel   (wave_sel0),
        .sample_out (voice0_sample),
        .voice_idle (voice_idle[0])
    );

    synth_voice_bend u_voice1 (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_en  (sample_en),
        .pitch_ratio(pitch_ratio),
        .env_preset(env_preset),
        .note       (note1),
        .note_on    (note_on1),
        .wave_sel   (wave_sel1),
        .sample_out (voice1_sample),
        .voice_idle (voice_idle[1])
    );

    synth_voice_bend u_voice2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_en  (sample_en),
        .pitch_ratio(pitch_ratio),
        .env_preset(env_preset),
        .note       (note2),
        .note_on    (note_on2),
        .wave_sel   (wave_sel2),
        .sample_out (voice2_sample),
        .voice_idle (voice_idle[2])
    );

    synth_voice_bend u_voice3 (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_en  (sample_en),
        .pitch_ratio(pitch_ratio),
        .env_preset(env_preset),
        .note       (note3),
        .note_on    (note_on3),
        .wave_sel   (wave_sel3),
        .sample_out (voice3_sample),
        .voice_idle (voice_idle[3])
    );

    wire signed [17:0] mix_sum;

    assign mix_sum =
          {{2{voice0_sample[15]}}, voice0_sample}
        + {{2{voice1_sample[15]}}, voice1_sample}
        + {{2{voice2_sample[15]}}, voice2_sample}
        + {{2{voice3_sample[15]}}, voice3_sample};

    assign sample_out = mix_sum >>> 2;

endmodule



