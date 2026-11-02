module frame_transition(input clk,input rst,input frame_tick,
 input commit_toggle,input target_bank,input [7:0] duration,input [1:0] mode,
 output reg completed_toggle,output reg display_valid,
 output reg old_bank,output reg new_bank,output reg [8:0] alpha,
 output reg busy);
 (*keep*) reg [2:0] sync_commit;(*keep*) reg [1:0] sync_bank;
 reg seen,pending,pending_bank,armed;reg [7:0] elapsed;
 wire [8:0] increment=duration==16?9'd16:duration==64?9'd4:9'd8;
 always @(posedge clk or posedge rst)begin
 if(rst)begin sync_commit<=0;sync_bank<=0;seen<=0;pending<=0;pending_bank<=0;armed<=0;
 completed_toggle<=0;display_valid<=0;old_bank<=0;new_bank<=0;alpha<=256;busy<=0;elapsed<=0;end
 else begin sync_commit<={sync_commit[1:0],commit_toggle};sync_bank<={sync_bank[0],target_bank};
 if(sync_commit[2]!=seen)begin seen<=sync_commit[2];pending<=1;pending_bank<=sync_bank[1];armed<=0;end
 if(frame_tick)begin
  if(pending&&!busy&&!armed)armed<=1;
  else if(pending&&!busy)begin pending<=0;
   if(!display_valid||mode==2)begin
    old_bank<=pending_bank;new_bank<=pending_bank;alpha<=256;display_valid<=1;
    completed_toggle<=~completed_toggle;
   end else begin old_bank<=new_bank;new_bank<=pending_bank;alpha<=0;busy<=1;elapsed<=0;end
  end else if(busy)begin
   if(alpha+increment>=256)begin alpha<=256;old_bank<=new_bank;busy<=0;completed_toggle<=~completed_toggle;end
   else begin alpha<=alpha+increment;elapsed<=elapsed+1;end
  end
 end end end
endmodule
