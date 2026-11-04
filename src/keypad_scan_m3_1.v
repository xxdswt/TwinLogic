// M3.1 independent per-key debounce. Physical polarity adapter stays in top.
// At 50 MHz: 100 us/row, 400 us/key sample interval.
// 8 opposite samples confirm press, 12 confirm release. Other keys cannot
// reset this key's counter. Only sampled stability is established by RTL;
// real contact bounce, matrix ghosting and RC still require hardware testing.
module keypad_scan #(
    parameter integer SCAN_DIV = 5000,
    parameter integer DEBOUNCE_FRAMES = 8,
    parameter integer RELEASE_FRAMES = 12
)(
    input wire clk,
    input wire rst_n,
    output reg [3:0] row_drive,
    input wire [3:0] col_n,
    output reg [15:0] key_state,
    output reg [15:0] key_pressed,
    output reg [15:0] key_released
);
    function integer width_for;
        input integer value;
        integer remaining;
        begin
            remaining=value-1;
            width_for=0;
            while(remaining>0) begin
                width_for=width_for+1;
                remaining=remaining>>1;
            end
            if(width_for<1) width_for=1;
        end
    endfunction
    localparam integer ROW_CYCLES=(SCAN_DIV<4)?4:SCAN_DIV;
    localparam integer PRESS_SAMPLES=(DEBOUNCE_FRAMES<1)?1:DEBOUNCE_FRAMES;
    localparam integer RELEASE_SAMPLES=(RELEASE_FRAMES<1)?1:RELEASE_FRAMES;
    localparam integer MAX_SAMPLES=(PRESS_SAMPLES>RELEASE_SAMPLES)?PRESS_SAMPLES:RELEASE_SAMPLES;
    localparam integer SCAN_WIDTH=width_for(ROW_CYCLES);
    localparam integer COUNT_WIDTH=width_for(MAX_SAMPLES);
    reg [1:0] row_idx;
    reg [SCAN_WIDTH-1:0] scan_count;
    reg [3:0] col_meta,col_sync;
    reg [COUNT_WIDTH-1:0] opposite_count [0:15];
    integer col,key_index,reset_index;
    always @(posedge clk) begin
        if(!rst_n) begin
            row_idx<=0;
            row_drive<=4'b0001;
            scan_count<=0;
            col_meta<=4'b1111;
            col_sync<=4'b1111;
            key_state<=0;
            key_pressed<=0;
            key_released<=0;
            for(reset_index=0;reset_index<16;reset_index=reset_index+1)
                opposite_count[reset_index]<=0;
        end else begin
            col_meta<=col_n;
            col_sync<=col_meta;
            key_pressed<=0;
            key_released<=0;
            if(scan_count==ROW_CYCLES-1) begin
                scan_count<=0;
                row_idx<=row_idx+1'b1;
                row_drive<={row_drive[2:0],row_drive[3]};
                for(col=0;col<4;col=col+1) begin
                    key_index={row_idx,2'b00}+col;
                    if((~col_sync[col])==key_state[key_index]) begin
                        opposite_count[key_index]<=0;
                    end else if((!col_sync[col] &&
                                 opposite_count[key_index]>=PRESS_SAMPLES-1) ||
                                (col_sync[col] &&
                                 opposite_count[key_index]>=RELEASE_SAMPLES-1)) begin
                        key_state[key_index]<=~col_sync[col];
                        key_pressed[key_index]<=~col_sync[col];
                        key_released[key_index]<=col_sync[col];
                        opposite_count[key_index]<=0;
                    end else begin
                        opposite_count[key_index]<=opposite_count[key_index]+1'b1;
                    end
                end
            end else scan_count<=scan_count+1'b1;
        end
    end
endmodule
