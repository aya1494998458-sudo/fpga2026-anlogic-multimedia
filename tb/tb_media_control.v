`timescale 1ns/1ps
module tb_media_control;
reg mc=0,vc=0;always #5 mc=~mc;always #17 vc=~vc;
reg rst=1,mounted=0,next=0;wire op;wire [1:0] index;wire bank,commit,complete,busy;
reg start=0,loaded=0,written=0;reg [5:0] work=0;reg [7:0] fc=0;
wire frame=fc==49;wire valid,oldbank,newbank,tbusy;wire [8:0] alpha;
media_control c(mc,rst,mounted,3'd3,start,loaded,4'd0,written,op,index,bank,commit,complete,next,busy);
frame_transition t(vc,rst,frame,commit,bank,8'd16,2'd0,complete,valid,oldbank,newbank,alpha,tbusy);
always @(posedge vc)if(rst)fc<=0;else fc<=frame?0:fc+1;
integer opens=0;reg protected_bank;
always @(negedge mc)begin
 start=0;loaded=0;written=0;
 if(op)begin
  if(tbusy)$fatal(1,"overwriting frame during transition");
  opens=opens+1;work=1;start=1;protected_bank=bank;
 end
 if(work!=0)begin
  if(bank!=protected_bank)$fatal(1,"bank changed during write");
  if(work==10)loaded=1;
  if(work==15)begin written=1;work=0;end else work=work+1;
 end
end
initial begin
 #50;rst=0;mounted=1;
 wait(valid&&!busy);if(opens!=1||newbank!=0)$fatal(1,"first commit");
 @(negedge vc);next=1;
 wait(tbusy);if(opens!=2||bank!=1)$fatal(1,"second load");
 // A next command while busy is consumed and ignored, not queued for overwrite.
 @(negedge vc);next=0;wait(!busy);repeat(200)@(negedge mc);
 if(opens!=2||newbank!=1)$fatal(1,"pending request leaked");
 @(negedge vc);next=1;wait(opens==3);if(bank!=0)$fatal(1,"old bank not released");
 $display("PASS complete-frame/transition mailbox, bank ownership and busy request suppression");$finish;
end
initial begin #1000000;$fatal(1,"media control timeout opens=%d",opens);end
endmodule
