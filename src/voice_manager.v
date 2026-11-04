// M2.3 reviewed copy of the local TwinLogic voice allocator.
// Original: F:/FPGA_Gowin/TwinLogic/m1_dds/src/voice_manager.v
// Interface and allocation behavior are intentionally preserved.
// - key_state must be stable/debounced. A pulse shorter than the audio
//   sample interval is not guaranteed to be captured by envelope_adsr.
// - A newly allocated voice stays reserved while voice_idle is still high
//   before the envelope sees its first sample_en; voice_has_key guards it.
// - Released voices are reclaimed only after ADSR idle. The allocation mask
//   uses the previous cycle's ownership, so reuse occurs one clock later.
// - There is no voice stealing. Extra held keys wait; lower key index wins.
// - Rapid re-press may use another idle voice while the former one releases.

module voice_manager (
    input  wire       clk,
    input  wire       rst_n,

    // Stable 16-key matrix state. Gates are levels, not event pulses.
    input  wire [15:0] key_state,

    // Idle status from four synthesizer voices.
    input  wire [3:0] voice_idle,

    // MIDI note outputs.
    output reg [6:0] note0,
    output reg [6:0] note1,
    output reg [6:0] note2,
    output reg [6:0] note3,

    // Level-sensitive note controls: a held key must span an audio sample_en.
    output reg note_on0,
    output reg note_on1,
    output reg note_on2,
    output reg note_on3
);

    // Record whether each key has been assigned.
    reg [15:0] key_assigned;

    // Record which voice belongs to each key.
    reg [1:0] key_voice [0:15];

    // Voice allocation state.
    reg [3:0] voice_in_use;
    reg [3:0] voice_has_key;

    // Temporary allocation mask.
    reg [3:0] used_voices;

    integer key_idx;
    integer voice_idx;
    integer chosen_voice;

    reg found_voice;


    // ------------------------------------------------
    // Key index to MIDI note mapping.
    // Key index = row * 4 + column.
    // C major scale, C4 to D6.
    // ------------------------------------------------

    function [6:0] key_to_midi;
        input [3:0] key_index;

        begin
            case (key_index)

                4'd0:  key_to_midi = 7'd60; // 1: C4
                4'd1:  key_to_midi = 7'd62; // 2: D4
                4'd2:  key_to_midi = 7'd64; // 3: E4
                4'd3:  key_to_midi = 7'd65; // A: F4

                4'd4:  key_to_midi = 7'd67; // 4: G4
                4'd5:  key_to_midi = 7'd69; // 5: A4
                4'd6:  key_to_midi = 7'd71; // 6: B4
                4'd7:  key_to_midi = 7'd72; // B: C5

                4'd8:  key_to_midi = 7'd74; // 7: D5
                4'd9:  key_to_midi = 7'd76; // 8: E5
                4'd10: key_to_midi = 7'd77; // 9: F5
                4'd11: key_to_midi = 7'd79; // C: G5

                4'd12: key_to_midi = 7'd81; // *: A5
                4'd13: key_to_midi = 7'd83; // 0: B5
                4'd14: key_to_midi = 7'd84; // #: C6
                4'd15: key_to_midi = 7'd86; // D: D6

                default: key_to_midi = 7'd60;

            endcase
        end
    endfunction


    // ------------------------------------------------
    // Voice allocation and release management.
    // ------------------------------------------------

    always @(posedge clk) begin

        if (!rst_n) begin

            key_assigned <= 16'd0;

            voice_in_use <= 4'd0;
            voice_has_key <= 4'd0;

            note0 <= 7'd60;
            note1 <= 7'd60;
            note2 <= 7'd60;
            note3 <= 7'd60;

            note_on0 <= 1'b0;
            note_on1 <= 1'b0;
            note_on2 <= 1'b0;
            note_on3 <= 1'b0;

            for (key_idx = 0; key_idx < 16;
                 key_idx = key_idx + 1) begin

                key_voice[key_idx] <= 2'd0;

            end

        end

        else begin

            // Reserve voices already allocated or releasing.
            used_voices = voice_in_use;


            // ----------------------------------------
            // 1. Detect released keys.
            // ----------------------------------------

            for (key_idx = 0; key_idx < 16;
                 key_idx = key_idx + 1) begin

                if (key_assigned[key_idx] &&
                    !key_state[key_idx]) begin

                    key_assigned[key_idx] <= 1'b0;

                    case (key_voice[key_idx])

                        2'd0: begin
                            note_on0 <= 1'b0;
                            voice_has_key[0] <= 1'b0;
                        end

                        2'd1: begin
                            note_on1 <= 1'b0;
                            voice_has_key[1] <= 1'b0;
                        end

                        2'd2: begin
                            note_on2 <= 1'b0;
                            voice_has_key[2] <= 1'b0;
                        end

                        2'd3: begin
                            note_on3 <= 1'b0;
                            voice_has_key[3] <= 1'b0;
                        end

                    endcase

                end

            end


            // ----------------------------------------
            // 2. Free voices whose ADSR has finished.
            // ----------------------------------------

            for (voice_idx = 0; voice_idx < 4;
                 voice_idx = voice_idx + 1) begin

                if (voice_in_use[voice_idx] &&
                    voice_idle[voice_idx] &&
                    !voice_has_key[voice_idx]) begin

                    voice_in_use[voice_idx] <= 1'b0;

                end

            end


            // ----------------------------------------
            // 3. Allocate voices to held, unassigned keys.
            // ----------------------------------------

            for (key_idx = 0; key_idx < 16;
                 key_idx = key_idx + 1) begin

                if (key_state[key_idx] &&
                    !key_assigned[key_idx]) begin

                    found_voice = 1'b0;
                    chosen_voice = -1;

                    // Find the first available voice.
                    for (voice_idx = 0; voice_idx < 4;
                         voice_idx = voice_idx + 1) begin

                        if (!found_voice &&
                            voice_idle[voice_idx] &&
                            !used_voices[voice_idx]) begin

                            found_voice = 1'b1;
                            chosen_voice = voice_idx;

                        end

                    end


                    if (found_voice) begin

                        // Reserve immediately to prevent
                        // multiple keys using the same voice.
                        used_voices[chosen_voice] = 1'b1;

                        key_assigned[key_idx] <= 1'b1;
                        key_voice[key_idx] <= chosen_voice[1:0];

                        case (chosen_voice)

                            0: begin
                                note0 <= key_to_midi(key_idx[3:0]);
                                note_on0 <= 1'b1;
                                voice_in_use[0] <= 1'b1;
                                voice_has_key[0] <= 1'b1;
                            end

                            1: begin
                                note1 <= key_to_midi(key_idx[3:0]);
                                note_on1 <= 1'b1;
                                voice_in_use[1] <= 1'b1;
                                voice_has_key[1] <= 1'b1;
                            end

                            2: begin
                                note2 <= key_to_midi(key_idx[3:0]);
                                note_on2 <= 1'b1;
                                voice_in_use[2] <= 1'b1;
                                voice_has_key[2] <= 1'b1;
                            end

                            3: begin
                                note3 <= key_to_midi(key_idx[3:0]);
                                note_on3 <= 1'b1;
                                voice_in_use[3] <= 1'b1;
                                voice_has_key[3] <= 1'b1;
                            end

                        endcase

                    end

                end

            end

        end

    end

endmodule
