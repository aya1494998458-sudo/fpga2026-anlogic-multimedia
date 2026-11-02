// Fetch PCM from an asynchronous FIFO on a 48kHz clock-enable, never on a
// generated logic clock. FIFO dout is registered, so sample_valid follows re.
module wav_audio_output #(parameter PIXEL_HZ=25000000,parameter PRIME_FRAMES=512)(
 input clk,input rst,input format_available,input format_error,
 input [47:0] fifo_data,input fifo_empty,input [12:0] fifo_count,
 output fifo_read,output reg selected,output reg underrun,
 output reg sample_valid,output reg [23:0] left_sample,right_sample);
 reg [24:0] phase;reg pending;
 (*keep*) reg [1:0] format_sync;(*keep*) reg [1:0] error_sync;
 wire [25:0] sum={1'b0,phase}+26'd48000;
 wire tick=sum>=PIXEL_HZ;
 assign fifo_read=tick&&selected&&!fifo_empty&&!error_sync[1];
 always @(posedge clk or posedge rst)begin
 if(rst)begin phase<=0;pending<=0;selected<=0;underrun<=0;sample_valid<=0;
 left_sample<=0;right_sample<=0;format_sync<=0;error_sync<=0;end
 else begin
 format_sync<={format_sync[0],format_available};error_sync<={error_sync[0],format_error};
 phase<=tick?sum-PIXEL_HZ:sum;
 sample_valid<=0;pending<=fifo_read;
 if(!selected && format_sync[1]&&!error_sync[1]&&fifo_count>=PRIME_FRAMES)selected<=1;
 if(error_sync[1])selected<=0;
 if(pending)begin sample_valid<=1;left_sample<=fifo_data[23:0];right_sample<=fifo_data[47:24];end
 else if(tick&&selected&&fifo_empty)begin
  sample_valid<=1;left_sample<=0;right_sample<=0;underrun<=1;
 end
 end end
endmodule
