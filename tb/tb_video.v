`timescale 1ns/1ps
module tb_video;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0;reg [63:0] pair={32'h0000ff00,32'hff000000};
reg [8:0] alpha=0,contrast=128;reg signed [8:0] brightness=0;
reg osd=0;wire [23:0] rgb;wire oh,ov,od,tick;
video_effects dut(clk,rst,hs,vs,de,pair,1'b1,1'b0,1'b1,alpha,2'd0,
 brightness,contrast,osd,1'b0,3'd0,2'd0,16'd640,16'd480,2'd0,1'b0,24'd0,4'd0,rgb,oh,ov,od,tick);
task setup_frame;begin
 @(negedge clk);de=0;vs=1;repeat(5)@(negedge clk);vs=0;repeat(5)@(negedge clk);de=1;
end endtask
task color_check;input [23:0] expected;begin
 repeat(6)@(negedge clk);if(!od||rgb!==expected)$fatal(1,"pixel got%h expected%h de%b",rgb,expected,od);
end endtask
integer i;
initial begin
 #30;rst=0;setup_frame();color_check(24'hff0000);
 alpha=128;color_check(24'h800080);
 alpha=256;color_check(24'h0000ff);
 brightness=127;setup_frame();color_check(24'h7f7fff);
 brightness=-128;setup_frame();color_check(24'h00007f);
 if(dut.enhance(8'd128,9'sd0,9'd128)!=128)$fatal(1,"neutral contrast");
 if(dut.enhance(8'd0,-9'sd128,9'd256)!=0)$fatal(1,"negative saturation");
 if(dut.enhance(8'd255,9'sd127,9'd256)!=255)$fatal(1,"positive saturation");
 // First F glyph at (0,0), foreground from ROM, then alpha background.
 brightness=0;osd=1;setup_frame();repeat(3)@(negedge clk);
 if(rgb!==24'hffe080)$fatal(1,"OSD foreground missing at first glyph: %h",rgb);
 repeat(10)@(negedge clk);if(rgb!==24'h000040)$fatal(1,"OSD background alpha mismatch: %h",rgb);
 de=0;vs=0;rst=1;repeat(3)@(negedge clk);rst=0;
 for(i=0;i<768;i=i+1)begin @(negedge clk);vs=1;@(negedge clk);vs=0;@(negedge clk);end
 if(dut.scroll!=0)$fatal(1,"scroll wrap boundary");
 $display("PASS two-image alpha endpoints/midpoint, enhancement saturation, OSD foreground/background alpha, scroll wrap and sync latency");$finish;
end
initial begin #100000;$fatal(1,"video timeout");end
endmodule

