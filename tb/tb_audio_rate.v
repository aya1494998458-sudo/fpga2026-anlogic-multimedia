`timescale 1ns/1ps
module tb_audio_rate;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [13:0] acc=0;wire [14:0] sum={1'b0,acc}+15'd15616;
wire ce=sum>=15625;wire bc,lr,sd;
hdmi_audio_tone_i2s_64fs dut(.I_mclk(clk),.I_ce(ce),.I_rst(rst),.O_i2s_BCLK(bc),.O_i2s_LRCK(lr),.O_i2s_DOUT(sd));
always @(posedge clk)if(rst)acc<=0;else acc<=ce?sum-15625:sum;
integer ticks=0,frames=0,cycles=0;reg last=0;
always @(posedge clk)if(!rst)begin
 if(ce)ticks=ticks+1;
 cycles=cycles+1;#1;
 if(last&&!lr)frames=frames+1;last=lr;
 if(cycles==15625)begin
  if(ticks!=15616||frames!=61)$fatal(1,"rate mismatch ticks=%d frames=%d",ticks,frames);
  $display("PASS serializer average Fs = (750MHz/61) * (15616/15625) / 256 = 48000 Hz");$finish;
 end
end
initial begin #30;rst=0;end
initial begin #200000;$fatal(1,"rate timeout");end
endmodule
