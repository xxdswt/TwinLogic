module dds_core (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_en,
    input  wire [31:0]        phase_inc,
    input  wire [1:0]         wave_sel,
    output reg signed [15:0]  sample_out    
);

    

    reg [31:0] phase_acc;

    wire [7:0] rom_addr;
    
    wire signed [15:0] sine_sample;
    wire signed [15:0] square_sample;
    
    wire [14:0] triangle_ramp;
    wire signed [15:0] triangle_sample;
    
    wire [14:0] saw_ramp;
    wire signed [15:0] saw_sample;
    

    // Generate 0 -> 32767 -> 0
    assign triangle_ramp =
        phase_acc[31] ? ~phase_acc[30:16] : phase_acc[30:16];

    // Shift to -16384 -> +16383 -> -16384
    assign triangle_sample =
        $signed({1'b0, triangle_ramp}) - 16'sd16384;
    
    assign saw_ramp = phase_acc[31:17];

    assign saw_sample =
        $signed({1'b0, saw_ramp}) - 16'sd16384;
    
    //phase accumulator
    always @(posedge clk) begin
        if (!rst_n) begin 
            phase_acc <= 32'd0;
        end
        else if (sample_en) begin
            phase_acc <= phase_acc + phase_inc;
        end
    end

    //ROM address
    assign rom_addr = phase_acc [31:24];

    // Sine wave
    sine_rom u_sine_rom (
        .addr (rom_addr),
        .data (sine_sample)
    );
    
    // Square wave
    assign square_sample = 
        phase_acc[31] ? -16'sd16384 : 16'sd16384;
        
    // Select waveform
    always @(*) begin
        case (wave_sel)
        
            2'd0:
                sample_out = sine_sample;
                
            2'd1:
                sample_out = square_sample;
                
            2'd2:
                sample_out = triangle_sample;
                
            2'd3:
                sample_out = saw_sample;
                
            default:
                sample_out = sine_sample;
                
        endcase
    end

endmodule