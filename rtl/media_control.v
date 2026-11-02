// Bundled-data mailbox: target_bank remains stable until video acknowledges
// transition completion. Neither frame can be overwritten during a blend.
module media_control(input mclk,input mrst,input mounted,input [2:0] file_count,
 input file_start,input loader_done,input [3:0] loader_error,input write_finish,
 output reg file_open,output reg [1:0] file_index,output reg target_bank,
 output reg commit_toggle,input completed_toggle,input next_toggle,
 output reg busy);
 (*keep*) reg [2:0] next_sync;(*keep*) reg [2:0] complete_sync;reg seen_next,seen_complete;
 reg [2:0] state;reg loaded,written;reg [3:0] wrstretch;
 always @(posedge mclk or posedge mrst)begin
 if(mrst)begin file_open<=0;file_index<=0;target_bank<=0;commit_toggle<=0;
 busy<=1;state<=0;loaded<=0;written<=0;wrstretch<=0;
 next_sync<=0;complete_sync<=0;seen_next<=0;seen_complete<=0;end
 else begin
 file_open<=0;next_sync<={next_sync[1:0],next_toggle};complete_sync<={complete_sync[1:0],completed_toggle};
 case(state)
 0:if(mounted&&file_count!=0)begin file_open<=1;loaded<=0;written<=0;state<=1;end
 1:begin
  if(write_finish)written<=1;
  if(loader_done)begin loaded<=1;if(loader_error!=0)begin state<=4;busy<=0;end end
  if(loaded&&written)begin commit_toggle<=~commit_toggle;state<=2;end
 end
 2:if(complete_sync[2]!=seen_complete)begin
  seen_complete<=complete_sync[2];seen_next<=next_sync[2];busy<=0;state<=3;
 end
 3:if(next_sync[2]!=seen_next)begin
  seen_next<=next_sync[2];busy<=1;target_bank<=~target_bank;
  file_index<=(file_index+1>=file_count)?0:file_index+1;
  state<=0;
 end
 4:if(next_sync[2]!=seen_next)begin seen_next<=next_sync[2];
  file_index<=(file_index+1>=file_count)?0:file_index+1;busy<=1;state<=0;end
 default:state<=0;
 endcase
 end end
endmodule
