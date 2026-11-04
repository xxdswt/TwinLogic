module envelope_adsr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_en,
    input  wire        note_on,
    output reg  [15:0] envelope,
    output wire        idle
);

    // Envelope parameters
    localparam [15:0] ATTACK_STEP    = 16'd64;
    localparam [15:0] DECAY_STEP     = 16'd32;
    localparam [15:0] RELEASE_STEP   = 16'd4;
    localparam [15:0] SUSTAIN_LEVEL  = 16'd39321;

    // ADSR states
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] ATTACK  = 3'd1;
    localparam [2:0] DECAY   = 3'd2;
    localparam [2:0] SUSTAIN = 3'd3;
    localparam [2:0] RELEASE = 3'd4;

    reg [2:0] state;
    assign idle = (state == IDLE);

    always @(posedge clk) begin

        if (!rst_n) begin
            envelope <= 16'd0;
            state    <= IDLE;
        end

        else if (sample_en) begin

            case (state)

                IDLE: begin
                    envelope <= 16'd0;

                    if (note_on)
                        state <= ATTACK;
                end


                ATTACK: begin

                    if (!note_on) begin
                        state <= RELEASE;
                    end
                    else if (envelope >= 16'd65471) begin
                        envelope <= 16'd65535;
                        state    <= DECAY;
                    end
                    else begin
                        envelope <= envelope + ATTACK_STEP;
                    end

                end


                DECAY: begin

                    if (!note_on) begin
                        state <= RELEASE;
                    end
                    else if (envelope <= SUSTAIN_LEVEL + DECAY_STEP) begin
                        envelope <= SUSTAIN_LEVEL;
                        state    <= SUSTAIN;
                    end
                    else begin
                        envelope <= envelope - DECAY_STEP;
                    end

                end


                SUSTAIN: begin

                    envelope <= SUSTAIN_LEVEL;

                    if (!note_on)
                        state <= RELEASE;

                end


                RELEASE: begin

                    if (note_on) begin
                        state <= ATTACK;
                    end
                    else if (envelope <= RELEASE_STEP) begin
                        envelope <= 16'd0;
                        state    <= IDLE;
                    end
                    else begin
                        envelope <= envelope - RELEASE_STEP;
                    end

                end


                default: begin
                    envelope <= 16'd0;
                    state    <= IDLE;
                end

            endcase

        end

    end

endmodule