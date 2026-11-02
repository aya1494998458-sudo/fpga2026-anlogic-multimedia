`timescale 1ns/1ps
module tb_wav_output;
reg clk=0;always #5 clk=~clk;
reg rst=1,available=0,err=0,empty=0;reg [47:0] data=0;
wire re,selected,underrun,valid;wire [23:0] left,right;
wav_audio_output dut(clk,rst,available,err,data,empty,13'd1024,re,selected,underrun,valid,left,right);
integer issued=0,received=0,previous=-1,cycles=0;reg starving=0;reg [23:0] dl,dr;
always @(posedge clk)if(!rst)begin
 cycles=cycles+1;
 if(re)begin issued=issued+1;dl=1000+issued;dr=24'hf00000-issued;data<={dr,dl};end
 #1;
 if(valid)begin
  if(left==0&&right==0)begin if(!starving)$fatal(1,"unexpected silence");end
  else begin
   received=received+1;
   if(left!==1000+received || right!==24'hf00000-received)$fatal(1,"PCM FIFO sample order");
   if(previous>0&&!starving && (cycles-previous<520||cycles-previous>521))$fatal(1,"48k sample pacing");
   previous=cycles;
  end
 end
end
initial begin
 #30;rst=0;available=1;wait(received==20);
 @(negedge clk);starving=1;empty=1;repeat(2000)@(negedge clk);
 if(!underrun)$fatal(1,"missing underrun diagnostic");
 empty=0;previous=-1;wait(received==30);starving=0;wait(received==50);
 err=1;repeat(5)@(negedge clk);if(selected)$fatal(1,"invalid WAV source still selected");
 $display("PASS WAV 48kHz cadence, stereo FIFO order, underrun silence/recovery and fallback");$finish;
end
initial begin #1000000;$fatal(1,"WAV output timeout");end
endmodule
