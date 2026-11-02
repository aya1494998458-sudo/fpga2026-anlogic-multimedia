`timescale 1ns/1ps
module tb_audio;
reg clk=0;always #5 clk=~clk;
reg rst=1,pv=0;reg signed [23:0] pcm=0;reg [9:0] x=0,y=0;
wire ink;wire [23:0] color;wire [7:0] peak;
audio_visualizer dut(clk,rst,pv,pcm,x,y,2'd2,ink,color,peak);
reg [23:0] samples[0:63];integer i,j,k,maxv,maxk;
initial begin
 $readmemh("assets/sine_bin5.hex",samples);
 #30;rst=0;
 for(i=0;i<512;i=i+1)begin
  for(j=0;j<16;j=j+1)begin
   @(negedge clk);pcm=samples[i%64];pv=1;@(negedge clk);pv=0;
  end
 end
 repeat(40)@(negedge clk);
 maxv=0;maxk=0;
 for(k=0;k<16;k=k+1)begin
  $display("bin%0d=%0d",k+1,dut.magnitude[k]);
  if(dut.magnitude[k]>maxv)begin maxv=dut.magnitude[k];maxk=k+1;end
 end
 if(maxk!=5||maxv<40)$fatal(1,"DFT expected bin5 peak; got %d=%d",maxk,maxv);
 if(!dut.have_wave)$fatal(1,"waveform capture incomplete");
 x=128;y=474;#1;if(!ink)$fatal(1,"spectrum renderer missing peak");
 $display("PASS true PCM waveform and 64-point DFT peak bin5");$finish;
end
initial begin #1000000;$fatal(1,"audio timeout");end
endmodule
