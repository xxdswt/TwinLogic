// 5x7 glyph in 8x8 page cell; bit zero is the upper pixel.
`default_nettype none
module oled_font(input wire [7:0] character,input wire [2:0] column,output reg [7:0] pixels);
 reg [39:0] glyph;
 always @* begin
  case(character)
   8'd48:glyph=40'h3e4549513e; // 0
   8'd49:glyph=40'h00407f4200; // 1
   8'd50:glyph=40'h4649516142; // 2
   8'd51:glyph=40'h3649494941; // 3
   8'd52:glyph=40'h107f121418; // 4
   8'd53:glyph=40'h314949494f; // 5
   8'd54:glyph=40'h304949493e; // 6
   8'd55:glyph=40'h0305097101; // 7
   8'd56:glyph=40'h3649494936; // 8
   8'd57:glyph=40'h3e49494906; // 9
   8'd65:glyph=40'h7e0909097e; // A
   8'd66:glyph=40'h364949497f; // B
   8'd67:glyph=40'h414141413e; // C
   8'd68:glyph=40'h3e4141417f; // D
   8'd69:glyph=40'h414949497f; // E
   8'd70:glyph=40'h010909097f; // F
   8'd71:glyph=40'h794949413e; // G
   8'd72:glyph=40'h7f0808087f; // H
   8'd73:glyph=40'h00417f4100; // I
   8'd74:glyph=40'h013f414020; // J
   8'd75:glyph=40'h412214087f; // K
   8'd76:glyph=40'h404040407f; // L
   8'd77:glyph=40'h7f020c027f; // M
   8'd78:glyph=40'h7f3008067f; // N
   8'd79:glyph=40'h3e4141413e; // O
   8'd80:glyph=40'h060909097f; // P
   8'd81:glyph=40'h5e2151413e; // Q
   8'd82:glyph=40'h462919097f; // R
   8'd83:glyph=40'h3149494946; // S
   8'd84:glyph=40'h01017f0101; // T
   8'd85:glyph=40'h3f4040403f; // U
   8'd86:glyph=40'h1f2040201f; // V
   8'd87:glyph=40'h7f2018207f; // W
   8'd88:glyph=40'h6314081463; // X
   8'd89:glyph=40'h0304780403; // Y
   8'd90:glyph=40'h4345495161; // Z
   8'd58:glyph=40'h0000360000; // :
   8'd45:glyph=40'h0808080808; // -
   8'd43:glyph=40'h08083e0808; // +
   8'd47:glyph=40'h0304081060; // /
   8'd46:glyph=40'h0000600000; // .
   default:glyph=0;
  endcase
  if(column>=1 && column<=5) pixels=glyph[(column-1)*8 +: 8];
  else pixels=0;
 end
endmodule
`default_nettype wire
