// Transaction-granular arbitration: a 512-byte SPI read is never preempted.
// Audio wins when both request; byte-stream backpressure bounds its requests.
module sd_sector_arbiter(input clk,input rst,
 input image_req,input [31:0] image_addr,input audio_req,input [31:0] audio_addr,
 output reg sec_req,output reg [31:0] sec_addr,
 input [7:0] sec_data,input sec_valid,input sec_end,
 output [7:0] image_data,output image_valid,output image_end,
 output [7:0] audio_data,output audio_valid,output audio_end,input audio_urgent);
 reg [1:0] state;reg owner;
 assign image_data=sec_data;assign audio_data=sec_data;
 assign image_valid=state==1&&!owner&&sec_valid;
 assign image_end=state==1&&!owner&&sec_end;
 assign audio_valid=state==1&&owner&&sec_valid;
 assign audio_end=state==1&&owner&&sec_end;
 always @(posedge clk or posedge rst)begin
 if(rst)begin state<=0;owner<=0;sec_req<=0;sec_addr<=0;end
 else case(state)
 0:if(audio_req||image_req)begin
  owner<=audio_req&&(!image_req||audio_urgent);
  sec_addr<=(audio_req&&(!image_req||audio_urgent))?audio_addr:image_addr;
  sec_req<=1;state<=1;
 end
 1:if(sec_end)begin sec_req<=0;state<=2;end
 2:if(owner?!audio_req:!image_req)state<=0;
 default:state<=0;
 endcase
 end
endmodule
