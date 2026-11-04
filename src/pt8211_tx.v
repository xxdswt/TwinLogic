module pt8211_tx (
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [15:0] sample_in,

    output reg                sample_en,
    output reg                bclk,
    output reg                ws,
    output reg                din
);

    // 50 MHz system clock
    // BCLK = 48k * 16 * 2 = 1.536 MHz
    // Two BCLK edges per bit period = 3.072 MHz

    reg [25:0] frac_acc;
    reg [4:0]  bit_pos;
    reg [15:0] frame_sample;

    wire [25:0] acc_next =
        frac_acc + 26'd3072000;

    always @(posedge clk) begin

        if (!rst_n) begin
            frac_acc     <= 26'd0;
            bit_pos      <= 5'd0;
            frame_sample <= 16'd0;

            sample_en    <= 1'b0;
            bclk         <= 1'b0;
            ws           <= 1'b0;
            din          <= 1'b0;
        end
        else begin
            sample_en <= 1'b0;

            if (acc_next >= 26'd50000000) begin

                frac_acc <=
                    acc_next - 26'd50000000;

                bclk <= ~bclk;

                if (!bclk) begin
                    // BCLK rising edge:
                    // DAC samples current DIN bit.

                    if (bit_pos == 5'd31) begin
                        bit_pos   <= 5'd0;
                        sample_en <= 1'b1;
                    end
                    else begin
                        bit_pos <= bit_pos + 5'd1;
                    end

                end
                else begin
                    // BCLK falling edge:
                    // Prepare data before next rising edge.

                    // 0 = right channel
                    // 1 = left channel
                    ws <= bit_pos[4];

                    if (bit_pos == 5'd0) begin
                        frame_sample <= sample_in;
                        din <= sample_in[15];
                    end
                    else begin
                        din <= frame_sample[
                            4'd15 - bit_pos[3:0]
                        ];
                    end
                end
            end
            else begin
                frac_acc <= acc_next;
            end
        end
    end

endmodule
