`timescale 1ns/1ps
module tb_math;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0;reg [31:0] a,b;wire done;wire [31:0] q;
udiv32 div(clk,rst,start,a,b,done,q);
reg frame=0,commit=0,bank=0;wire completed,valid,oldbank,newbank,busy;wire [8:0] alpha;
frame_transition tr(clk,rst,frame,commit,bank,8'd16,2'd0,completed,valid,oldbank,newbank,alpha,busy);
task divide;input [31:0] x,y;begin
 @(negedge clk);a=x;b=y;start=1;@(negedge clk);start=0;
 wait(done);#1;if(q!==x/y)$fatal(1,"division %d/%d got%d",x,y,q);
end endtask
task tick;begin @(negedge clk);frame=1;@(negedge clk);frame=0;end endtask
integer i;reg before_ack;
initial begin
 #30;rst=0;
 divide(32'hffffffff,123);divide(640*479,639);divide(65536*639,639);divide(0,100);
 for(i=1;i<30;i=i+1)divide(i*1234567,i*23);
 @(negedge clk);commit=1;repeat(6)@(negedge clk);tick();#1;
 if(valid)$fatal(1,"must wait for FIFO to refresh a complete frame");tick();#1;
 if(!valid || alpha!=256 || busy)$fatal(1,"first image commit");
 before_ack=completed;
 @(negedge clk);commit=0;bank=1;repeat(6)@(negedge clk);tick();tick();#1;
 if(!busy||alpha!=0||oldbank!=0||newbank!=1)$fatal(1,"fade start");
 for(i=0;i<16;i=i+1)begin tick();#1;if(i<15 && !busy)$fatal(1,"early completion");end
 if(busy||alpha!=256||completed==before_ack)$fatal(1,"fade endpoint");
 $display("PASS division and frame-boundary double-buffer fade");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
