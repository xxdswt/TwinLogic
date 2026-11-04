// M4: 32 physical voices; accepted four-voice performance plus adjustable 32-tone TEST.
// Physical mapping measured in M2: rows P8..P5, columns P4..P1. Unchanged wiring.
`default_nettype none
module twinlogic_audio_top #(
    parameter integer KEYPAD_SCAN_DIV = 5000,
    parameter integer KEYPAD_DEBOUNCE_FRAMES = 8,
    parameter integer KEYPAD_RELEASE_FRAMES = 12,
    parameter integer BUTTON_DEBOUNCE_CYCLES = 100000,
    parameter integer CONTROL_CHORD_SAMPLES = 24000,
    parameter integer CONTROL_REPEAT_SAMPLES = 4800,
    parameter integer STATUS_REPORT_CYCLES = 5000000,
    parameter integer OLED_I2C_QUARTER_CYCLES = 125,
    parameter integer OLED_TIMEOUT_CYCLES = 50000,
    parameter integer OLED_POWERUP_CYCLES = 5000000,
    parameter integer OLED_RETRY_CYCLES = 25000000,
    parameter integer OLED_FRAME_PAUSE_CYCLES = 1000000,
    parameter integer OLED_COLUMN_OFFSET = 0,
    parameter integer BOARD_DEMO_MODE = 0
)(
    input  wire sys_clk,
    input  wire rst_n,
    input  wire key0_n,
    input  wire key2_n,
    inout  wire [3:0] keypad_row_n,
    input  wire [3:0] keypad_col_n,
    output wire i2s_bclk,
    output wire i2s_lrck,
    output wire i2s_din,
    output wire uart_tx,
    inout wire oled_scl, oled_sda,
    output wire pa_en
);
    // Preserve original amplifier setting and synchronous active-low reset.
    assign pa_en = 1'b0;
    reg key0_meta, key0_sync;
    reg key2_meta, key2_sync;
    always @(posedge sys_clk) begin
        if (!rst_n) begin
            key0_meta <= 1'b1;
            key0_sync <= 1'b1;
            key2_meta <= 1'b1;
            key2_sync <= 1'b1;
        end else begin
            key0_meta <= key0_n;
            key0_sync <= key0_meta;
            key2_meta <= key2_n;
            key2_sync <= key2_meta;
        end
    end

    wire key0_pressed = ~key0_sync;
    wire key2_pressed = ~key2_sync;
    wire sample_en;
    wire signed [15:0] mixed_sample;
    wire [3:0] voice_idle;
    wire [6:0] note0, note1, note2, note3;
    wire note_on0, note_on1, note_on2, note_on3;
    wire [3:0] row_drive;
    wire [15:0] key_state;
    wire [15:0] key_pressed, key_released;
    wire [15:0] managed_key_state;

    // Matrix keys own gates; board buttons now bend pitch without retrigger.
    assign managed_key_state = key_state;
    wire [20:0] pitch_ratio;
    wire down_stable,up_stable,bend_down,bend_up;
    wire [2:0] control_mode;
    wire [4:0] test_focus;
    wire [31:0] test_mute;
    wire [31:0] all_voice_idle;
    wire [5:0] active_count;
    assign voice_idle=all_voice_idle[3:0];
    wire [4:0] volume_level;
    wire [1:0] timbre,env_preset;
    wire [31:0] test_mask;
    wire test_pitch_hi=(control_mode==4) && key_state[0];
    wire test_mode=(BOARD_DEMO_MODE==0 && control_mode==4);
    wire test_all=test_mode && key_state[3]; // Hold matrix A for all32, release for solo.
    reg test_all_previous;
    reg [4:0] focus_previous;
    always @(posedge sys_clk) begin
      if(!rst_n)begin test_all_previous<=0;focus_previous<=0;end
      else begin test_all_previous<=test_all;focus_previous<=test_focus;end
    end
    reg test_mode_previous;
    always @(posedge sys_clk) begin
        if(!rst_n) test_mode_previous<=0;
        else test_mode_previous<=test_mode;
    end
    wire engine_rst_n=rst_n && (test_mode_previous==test_mode) && (test_all_previous==test_all) && !(test_mode && !test_all && focus_previous!=test_focus);
    button_stable #(.CYCLES(BUTTON_DEBOUNCE_CYCLES)) u_down(
        .clk(sys_clk),.rst_n(rst_n),.pressed_in(key0_pressed),.pressed(down_stable));
    button_stable #(.CYCLES(BUTTON_DEBOUNCE_CYCLES)) u_up(
        .clk(sys_clk),.rst_n(rst_n),.pressed_in(key2_pressed),.pressed(up_stable));
    parallel_controls #(.CHORD_SAMPLES(CONTROL_CHORD_SAMPLES),.REPEAT_SAMPLES(CONTROL_REPEAT_SAMPLES)) u_controls(
        .clk(sys_clk),.rst_n(rst_n),.sample_en(sample_en),
        .key_down(down_stable),.key_up(up_stable),.mode(control_mode),.volume_level(volume_level),
        .timbre(timbre),.env_preset(env_preset),.test_focus(test_focus),.test_mute(test_mute),
        .bend_down(bend_down),.bend_up(bend_up),.test_mask(test_mask));
    wire [15:0] gain_q15;
    volume_smooth u_volume(.clk(sys_clk),.rst_n(rst_n),.sample_en(sample_en),.level(volume_level),.gain_q15(gain_q15));
    wire oled_ready;
    wire [1:0] oled_error;
    wire [6:0] oled_address;
    wire [15:0] oled_frames;
    oled_status32 #(.I2C_QUARTER_CYCLES(OLED_I2C_QUARTER_CYCLES),
        .I2C_TIMEOUT_CYCLES(OLED_TIMEOUT_CYCLES),.POWERUP_CYCLES(OLED_POWERUP_CYCLES),
        .RETRY_CYCLES(OLED_RETRY_CYCLES),.FRAME_PAUSE_CYCLES(OLED_FRAME_PAUSE_CYCLES),
        .COLUMN_OFFSET(OLED_COLUMN_OFFSET)) u_oled(
        .clk(sys_clk),.rst_n(rst_n),.mode(control_mode),.volume_level(volume_level),
        .timbre(timbre),.env_preset(env_preset),.key_state(key_state),.active_count(active_count),
        .test_focus(test_focus),.focused_mute(test_mute[test_focus]),.test_pitch_hi(test_pitch_hi),.test_all(test_all),.scl(oled_scl),.sda(oled_sda),
        .ready(oled_ready),.address(oled_address),.error(oled_error),.frames(oled_frames));
    parallel_status #(.REPORT_CYCLES(STATUS_REPORT_CYCLES)) u_status(
        .clk(sys_clk),.rst_n(rst_n),.mode(control_mode),.volume_level(volume_level),
        .timbre(timbre),.env_preset(env_preset),.test_mask(test_mask[3:0]),.test_pitch_hi(test_pitch_hi),.tx(uart_tx),
        .active_count(active_count),.test_focus(test_focus),.focused_mute(test_mute[test_focus]),.test_all(test_all),
        .oled_ready(oled_ready),.oled_error(oled_error),.oled_address(oled_address));
    function [1:0] selected_wave;
        input [1:0] voice_index;
        begin
            if(BOARD_DEMO_MODE!=0 || timbre==0) selected_wave=voice_index;
            else case(timbre)
                1:selected_wave=0;
                2:selected_wave=2;
                default:selected_wave=3;
            endcase
        end
    endfunction
    pitch_ratio_ctrl u_pitch_ctrl (
        .clk(sys_clk), .rst_n(rst_n), .sample_en(sample_en),
        .bend_down(bend_down && (BOARD_DEMO_MODE==0)),
        .bend_up(bend_up && (BOARD_DEMO_MODE==0)),
        .pitch_ratio(pitch_ratio)
    );
    genvar row;
    generate
        for (row = 0; row < 4; row = row + 1) begin : g_rows
            // row_drive is logical active-HIGH selection, NOT a physical
            // voltage. Sink the selected row; leave inactive rows undriven.
            assign keypad_row_n[row] =
                (rst_n && !BOARD_DEMO_MODE && row_drive[row]) ? 1'b0 : 1'bz;
        end
        if (BOARD_DEMO_MODE == 0) begin : g_keypad
            keypad_scan #(
                .SCAN_DIV(KEYPAD_SCAN_DIV),
                .DEBOUNCE_FRAMES(KEYPAD_DEBOUNCE_FRAMES),
                .RELEASE_FRAMES(KEYPAD_RELEASE_FRAMES)
            ) u_keypad (
                .clk(sys_clk), .rst_n(rst_n),
                .row_drive(row_drive), .col_n(keypad_col_n),
                .key_state(key_state),
                .key_pressed(key_pressed), .key_released(key_released)
            );
            voice_manager u_manager (
                .clk(sys_clk), .rst_n(rst_n && !test_mode),
                .key_state(managed_key_state), .voice_idle(voice_idle),
        .note0(note0), .note1(note1), .note2(note2), .note3(note3),
                .note_on0(note_on0), .note_on1(note_on1),
                .note_on2(note_on2), .note_on3(note_on3)
            );
        end else begin : g_board_demo
            // Exact original fixed voice/pitch/button behavior for regression.
            assign row_drive = 4'b0000;
            assign key_state = 16'h0000;
            assign key_pressed = 16'h0000;
            assign key_released = 16'h0000;
            assign note0 = 7'd60;
            assign note1 = 7'd64;
            assign note2 = 7'd67;
            assign note3 = 7'd72;
            assign note_on0 = key0_pressed;
            assign note_on1 = key0_pressed;
            assign note_on2 = key2_pressed;
            assign note_on3 = key2_pressed;
        end
    endgenerate

    wire [223:0] engine_notes;
    wire [31:0] engine_gates;
    wire [63:0] engine_waves;
    genvar v;
    generate for(v=0;v<32;v=v+1) begin:g_config
        localparam [6:0] TEST_NOTE=(v==0)?69:(v==21)?48:48+v;
        wire [6:0] normal_note;
        wire normal_gate;
        if(v==0) begin assign normal_note=note0;assign normal_gate=note_on0;end
        else if(v==1)begin assign normal_note=note1;assign normal_gate=note_on1;end
        else if(v==2)begin assign normal_note=note2;assign normal_gate=note_on2;end
        else if(v==3)begin assign normal_note=note3;assign normal_gate=note_on3;end
        else begin assign normal_note=0;assign normal_gate=0;end
        assign engine_notes[v*7+:7]=test_mode ? (TEST_NOTE+((test_pitch_hi && test_focus==v)?7'd36:7'd0)):normal_note;
        assign engine_gates[v]=test_mode?(test_mask[v] && (test_all || test_focus==v)):normal_gate;
        assign engine_waves[v*2+:2]=test_mode?2'd0:selected_wave(v%4);
    end endgenerate
    // Balanced, registered popcount used only for feedback.
    reg [5:0] active_registered;
    integer ac;
    reg [5:0] active_next;
    always @* begin
        active_next=0;
        for(ac=0;ac<32;ac=ac+1)active_next=active_next+{5'b0,!all_voice_idle[ac]};
    end
    always @(posedge sys_clk) begin
        if(!rst_n)active_registered<=0;else active_registered<=active_next;
    end
    assign active_count=active_registered;
    parallel_engine u_engine(
        .clk(sys_clk),.rst_n(engine_rst_n),.sample_en(sample_en),.test_mode(test_mode),.test_all(test_all),
        .pitch_ratio(test_mode?21'd1048576:pitch_ratio),
        .env_preset((BOARD_DEMO_MODE!=0)?2'd0:(test_mode?2'd2:env_preset)),
        .notes(engine_notes),.gates(engine_gates),.waves(engine_waves),
        .sample_out(mixed_sample),.voice_idle(all_voice_idle),.phase_steps_debug());

    // Recording variant: +6 dB digital gain in both modes.
    // Break DDS/envelope/mix/volume into two sys_clk pipeline stages.
    // Audio sample_en is ~1042 clocks apart; original serializer is unchanged.
    reg signed [15:0] safe_base;
    always @(posedge sys_clk) begin
        if(!rst_n) safe_base<=0;
        else safe_base<=mixed_sample >>> (test_mode?3:7);
    end
    wire signed [16:0] gain_signed = {1'b0,((BOARD_DEMO_MODE!=0)?16'd32768:gain_q15)};
    reg signed [32:0] volume_product;
    always @(posedge sys_clk) begin
        if(!rst_n) volume_product<=0;
        else volume_product<=safe_base * gain_signed;
    end
    wire signed [32:0] volume_scaled = volume_product >>> 15;
    wire signed [15:0] safe_audio = volume_scaled[15:0];
    pt8211_tx u_audio (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_in(safe_audio), .sample_en(sample_en),
        .bclk(i2s_bclk), .ws(i2s_lrck), .din(i2s_din)
    );
endmodule
`default_nettype wire





