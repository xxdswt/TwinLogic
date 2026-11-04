`timescale 1ns/1ps
// Independent receiver of actual BCLK/WS/DIN pins. No internal audio bus is
// used to validate the waveform. This is digital simulation, not DAC capture.
module tb_solo_serial;
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,k0=1,k2=1;
 reg [15:0] keys=0;
 tri [3:0] rows;
 reg [3:0] cols;
 tri1 scl,sda;
 wire bclk,ws,din,pa,tx;
 integer r,c;
 twinlogic_audio_top #(.KEYPAD_SCAN_DIV(16),.KEYPAD_DEBOUNCE_FRAMES(2),
 .KEYPAD_RELEASE_FRAMES(2),.BUTTON_DEBOUNCE_CYCLES(4),
 .CONTROL_CHORD_SAMPLES(4),.CONTROL_REPEAT_SAMPLES(10000)) dut(
 .sys_clk(clk),.rst_n(rst_n),.key0_n(k0),.key2_n(k2),
 .keypad_row_n(rows),.keypad_col_n(cols),.i2s_bclk(bclk),.i2s_lrck(ws),
 .i2s_din(din),.pa_en(pa),.uart_tx(tx),.oled_scl(scl),.oled_sda(sda));
 always @* begin
  cols=15;
  for(r=0;r<4;r=r+1)for(c=0;c<4;c=c+1)
   if(rows[r]===0 && keys[r*4+c])cols[c]=0;
 end
 reg [15:0] shift=0,right_word=0;
 reg channel=0,have_channel=0,have_right=0;
 integer bit_count=0,frame_count=0,sample_value;
 integer capture=0,n=0,minimum=0,maximum=0,previous_value=0;
 integer crosses=0,first_cross=0,last_cross=0,nonzero=0;
 real first_ns=0,last_ns=0,frequency=0,sample_rate=0;
 integer data_file;
 event frame_ready;
 always @(posedge bclk or negedge rst_n) begin
  if(!rst_n)begin
   shift=0;right_word=0;channel=0;have_channel=0;have_right=0;
   bit_count=0;frame_count=0;
  end else begin
   if((din!==1'b0 && din!==1'b1) || (ws!==1'b0 && ws!==1'b1))
    $fatal(1,"unknown serial pin level");
   if(!have_channel || ws!=channel)begin
    if(have_channel && bit_count!=16)$fatal(1,"channel word is not 16 bits");
    channel=ws;have_channel=1;bit_count=1;shift={15'b0,din};
   end else begin
    if(bit_count>=16)$fatal(1,"channel exceeded 16 bits");
    shift={shift[14:0],din};bit_count=bit_count+1;
   end
   if(bit_count==16)begin
    if(channel==0)begin right_word=shift;have_right=1;end
    else if(have_right)begin
     if(shift!==right_word)$fatal(1,"stereo words differ: R=%h L=%h",right_word,shift);
     frame_count=frame_count+1;
     sample_value=$signed(shift);
     if(capture!=0)begin
      if(sample_value>2047 || sample_value< -2048)$fatal(1,"decoded output exceeds safe bound: %0d",sample_value);
      n=n+1;
      if(n==1)first_ns=$realtime;
      last_ns=$realtime;
      if(sample_value>maximum)maximum=sample_value;
      if(sample_value<minimum)minimum=sample_value;
      if(sample_value!=0)nonzero=nonzero+1;
      if(n>1 && previous_value<=0 && sample_value>0)begin
       if(crosses==0)first_cross=n;
       last_cross=n;crosses=crosses+1;
      end
      previous_value=sample_value;
      $fwrite(data_file,"%0d,%0d,%0.3f,%0d\n",capture,n,$realtime,sample_value);
     end
     ->frame_ready;
    end
   end
  end
 end
 task next_mode;begin
  @(negedge clk);k0=0;k2=0;#200000;k0=1;k2=1;#100000;
 end endtask
 task collect;input integer kind,words;begin
  @(negedge clk);capture=kind;n=0;minimum=0;maximum=0;previous_value=0;
  crosses=0;first_cross=0;last_cross=0;nonzero=0;first_ns=0;last_ns=0;
  repeat(words)@(frame_ready);
  @(negedge clk);capture=0;
  if(n!=words)$fatal(1,"capture word count %0d expected %0d",n,words);
  sample_rate=(n-1)*1000000000.0/(last_ns-first_ns);
  if(sample_rate<47999 || sample_rate>48001)$fatal(1,"serial sample rate %f",sample_rate);
 end endtask
 task check_solo;begin
  if(maximum<1900 || minimum> -1900)$fatal(1,"decoded solo too quiet: %0d %0d",maximum,minimum);
  if(crosses<4)$fatal(1,"too few solo cycles");
  frequency=(crosses-1)*48000.0/(last_cross-first_cross);
  if(frequency<438 || frequency>442)$fatal(1,"decoded solo is not 440Hz: %f",frequency);
  $display("PASS decoded SOLO440: %0.6f Hz, peaks %0d/%0d, stereo duplicates, Fs=%0.6f Hz",frequency,minimum,maximum,sample_rate);
 end endtask
 initial begin
  data_file=$fopen("solo_serial_words.csv","w");
  if(!data_file)$fatal(1,"cannot open serial capture");
  $fwrite(data_file,"capture,sample,time_ns,value\n");
  repeat(8)@(negedge clk);rst_n=1;
  next_mode;next_mode;next_mode;next_mode;
  if(dut.control_mode!==4)$fatal(1,"TEST entry");
  wait(dut.active_count==1);repeat(100)@(frame_ready);
  collect(1,1024);check_solo;
  @(negedge clk);keys=16'h0008;
  wait(dut.active_count==32);repeat(100)@(frame_ready);
  collect(2,512);
  if(maximum<32 || minimum> -32 || nonzero<400)$fatal(1,"full32 decoded signal absent or invalid");
  $display("PASS decoded full32: bounded stereo signal, actual active_count32, peaks %0d/%0d",minimum,maximum);
  @(negedge clk);keys=0;
  wait(dut.active_count==1);repeat(100)@(frame_ready);
  collect(3,512);check_solo;
  $fclose(data_file);
  $display("PASS tb_solo_serial: pin-level mono440, exact stereo words, holdA32 and solo return; digital simulation only");
  $finish;
 end
 initial begin #120000000;$fatal(1,"serial solo test timeout");end
endmodule
