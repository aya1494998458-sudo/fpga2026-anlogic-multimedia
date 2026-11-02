// One root-directory WAV, automatically reopened at EOF without flushing PCM.
// This makes the last sample flow directly into the next loop when prebuffered.
module wav_file_control(input clk,input rst,input mounted,input [2:0] count,
 input parser_done,input format_ok,input [3:0] parser_error,input [3:0] fs_error,
 output reg file_open,output reg available,output reg failed);
 reg [1:0] state;
 always @(posedge clk or posedge rst)begin
 if(rst)begin state<=0;file_open<=0;available<=0;failed<=0;end
 else begin file_open<=0;
 if(format_ok)available<=1;
 if(parser_error!=0||fs_error!=0)begin failed<=1;available<=0;state<=3;end
 else case(state)
 0:if(mounted&&count!=0)begin file_open<=1;state<=1;end
 1:if(parser_done)state<=2;
 2:state<=0;
 default:;
 endcase
 end end
endmodule
