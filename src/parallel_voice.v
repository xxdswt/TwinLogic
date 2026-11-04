module parallel_voice (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_en,
    input  wire [20:0]        pitch_ratio,
    input  wire [1:0]         env_preset,
    input  wire [6:0]         note,
    input  wire               note_on,
    input  wire [1:0]         wave_sel,
    output wire signed [15:0] sample_out,
    output wire [31:0] phase_step_debug,
    output wire               voice_idle
);

    wire [31:0] phase_inc;
    wire [31:0] base_phase_inc;
    wire signed [15:0] dds_sample;
    wire [15:0] envelope;
    wire envelope_idle;

    wire signed [16:0] dds_sample_ext;
    wire signed [16:0] envelope_ext;
    wire signed [33:0] amp_product;

    note_to_phase_inc u_note_to_phase_inc (
        .note      (note),
        .phase_inc (base_phase_inc)
    );

    phase_scale_q20 u_pitch_scale (
        .clk(clk), .rst_n(rst_n), .base_phase_inc(base_phase_inc),
        .pitch_ratio(pitch_ratio), .phase_inc(phase_inc)
    );
    dds_core u_dds_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_en  (sample_en),
        .phase_inc  (phase_inc),
        .wave_sel   (wave_sel),
        .sample_out (dds_sample)
    );
    
    envelope_adsr_live u_envelope_adsr (
        .env_preset(env_preset),
        .clk       (clk),
        .rst_n     (rst_n),
        .sample_en (sample_en),
        .note_on   (note_on),
        .envelope  (envelope),
        .idle      (envelope_idle)
    );

    assign phase_step_debug=phase_inc;
    reg signed [15:0] dds_registered;
    reg [15:0] envelope_registered;
    reg signed [33:0] amplitude_registered;
    always @(posedge clk) begin
        if(!rst_n) begin dds_registered<=0;envelope_registered<=0;amplitude_registered<=0;end
        else begin
            dds_registered<=dds_sample;
            envelope_registered<=envelope;
            amplitude_registered<=amp_product;
        end
    end
    assign dds_sample_ext = {dds_registered[15], dds_registered};
    assign envelope_ext   = {1'b0, envelope_registered};
    assign amp_product = dds_sample_ext * envelope_ext;
    assign sample_out = amplitude_registered[31:16];

    assign voice_idle = envelope_idle;
endmodule

