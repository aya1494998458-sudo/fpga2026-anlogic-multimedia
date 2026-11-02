`timescale 1ns/1ps
module tb_ui;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [3:0] keys=4'hf,sw=0;reg frame=0;
wire next,auto_play,osd,mute;wire signed [8:0] brightness;wire [8:0] contrast;
wire [2:0] page;wire [1:0] visual,transition;wire [7:0] duration;
media_ui #(.CLK_HZ(100)) dut(clk,rst,keys,sw,frame,1'b0,next,auto_play,osd,brightness,contrast,page,visual,transition,duration,mute);
task press;input integer key;begin
 @(negedge clk);keys[key]=0;repeat(8)@(negedge clk);keys[key]=1;repeat(8)@(negedge clk);
end endtask
task switches;input [3:0] value;begin @(negedge clk);sw=value;repeat(8)@(negedge clk);end endtask
integer i;reg old_next;
initial begin #30;rst=0;
 switches(4'b1000);if(page!=0||!osd||auto_play)$fatal(1,"GPIO switch mapping");
 press(1);if(!next)$fatal(1,"KEY2 next");
 press(2);if(!mute)$fatal(1,"KEY3 mute on page0");
 press(3);if(visual!=2)$fatal(1,"KEY4 visualization on page0");
 switches(4'b1001);if(page!=1)$fatal(1,"brightness page");
 press(2);if(brightness!=16)$fatal(1,"increase brightness");
 @(negedge clk);keys[2]=0;repeat(200)@(negedge clk);
 if(brightness!=32)$fatal(1,"held button repeated or entered old long-press menu");
 keys[2]=1;repeat(8)@(negedge clk);
 for(i=0;i<20;i=i+1)press(3);if(brightness!=-128)$fatal(1,"brightness clamp");
 switches(4'b1010);press(2);if(contrast!=160)$fatal(1,"contrast page");
 switches(4'b1011);press(2);press(3);if(transition!=1||duration!=64)$fatal(1,"effects page");
 switches(4'b0100);if(!auto_play||osd||page!=0)$fatal(1,"independent auto and OSD switches");
 old_next=next;
 for(i=0;i<180;i=i+1)begin @(negedge clk);frame=1;@(negedge clk);frame=0;end
 if(next==old_next)$fatal(1,"automatic playback switch");
 $display("PASS KEY2/3/4 single presses, four direct switches, no long-press action, page controls and auto playback");$finish;
end
initial begin #100000;$fatal(1,"UI timeout");end
endmodule
