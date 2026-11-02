`timescale 1ns/1ps
module tb_video_axis;
reg clk=0;always #5 clk=~clk;
reg rst=1,vs=0,de=0;reg [23:0] rgb=0;
wire user,valid,last;wire [23:0] out;
video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,user,valid,last,out);
integer x,y,px=0,lines=0,frames=0;
always @(negedge clk)if(valid)begin
 if(out!==lines*640+px)$fatal(1,"AXIS pixel mismatch");
 if(user)begin frames=frames+1;if(px!=0||lines!=0)$fatal(1,"misplaced SOF");end
 if(last!==(px==639))$fatal(1,"TLAST missing/misplaced at x=%d",px);
 if(px==639)begin px=0;lines=lines+1;end else px=px+1;
end
initial begin
 #30;rst=0;@(negedge clk);vs=1;repeat(3)@(negedge clk);vs=0;
 for(y=0;y<480;y=y+1)begin
 for(x=0;x<640;x=x+1)begin @(negedge clk);de=1;rgb=y*640+x;end
 @(negedge clk);de=0;repeat(159)@(negedge clk);
 end
 repeat(3)@(negedge clk);
 if(lines!=480||frames!=1)$fatal(1,"frame count");
 $display("PASS complete 640x480 AXIS frame, exact TLAST on pixel640 and one SOF");$finish;
end
endmodule
