// Streaming RIFF/WAVE integer PCM decoder. 48kHz, mono/stereo, 16/24-bit.
// Unknown chunks and odd padding are skipped; backpressure preserves samples.
module wav_pcm_decoder(input clk,input rst,input start,input [31:0] file_size,
 input [7:0] data,input valid,output ready,input eof,
 output reg [47:0] frame,output reg frame_valid,input frame_ready,
 output reg format_ok,output reg done,output reg [3:0] error);
 localparam IDLE=0,RIFF=1,CHUNK=2,DECODE=3,FMT=4,CHECK_FMT=5,
 SKIP=6,PAD=7,PCM=8,DRAIN=9,FINISH=10;
 reg [3:0] state;reg [31:0] consumed,left,chunk_id,chunk_size,riff_size;
 reg [31:0] riff_id,wave_id,sample_rate,byte_rate;
 reg [15:0] encoding,channels,block_align,bits;
 reg [5:0] index;reg seen_fmt,odd;reg [2:0] sample_byte;
 reg [7:0] b0,b1;reg [23:0] lsample;
 wire accepting=state==RIFF||state==CHUNK||state==FMT||state==SKIP||state==PAD||
                (state==PCM&&(!frame_valid||frame_ready))||state==DRAIN;
 assign ready=accepting;
 wire [23:0] decoded=bits==16?{data,b0,8'd0}:{data,b1,b0};
 always @(posedge clk or posedge rst)begin
 if(rst)begin state<=IDLE;frame<=0;frame_valid<=0;format_ok<=0;done<=0;error<=0;
 consumed<=0;index<=0;left<=0;seen_fmt<=0;sample_byte<=0;odd<=0;end
 else begin done<=0;
 if(frame_valid&&frame_ready)frame_valid<=0;
 if(valid&&ready)consumed<=consumed+1;
 if(start)begin state<=RIFF;index<=0;consumed<=0;seen_fmt<=0;format_ok<=0;error<=0;frame_valid<=0;sample_byte<=0;end
 else begin
 // A truncated file never leaves the parser waiting for missing bytes.
 if(eof && state!=IDLE && state!=FINISH && state!=DRAIN)begin
  if(state!=PCM || left!=1)begin error<=4'd3;format_ok<=0;state<=FINISH;end
 end
 case(state)
 RIFF:if(valid&&ready)begin
  if(index<4)riff_id[index*8+:8]<=data;
  else if(index<8)riff_size[(index-4)*8+:8]<=data;
  else wave_id[(index-8)*8+:8]<=data;
  if(index==11)begin index<=0;state<=11;end else index<=index+1;
 end
 11:if(riff_id!=32'h46464952 || wave_id!=32'h45564157 || riff_size<4 ||
       {1'b0,riff_size}+33'd8>{1'b0,file_size})begin error<=1;state<=DRAIN;end
    else begin state<=CHUNK;index<=0;end
 CHUNK:if(valid&&ready)begin
  if(index<4)chunk_id[index*8+:8]<=data;else chunk_size[(index-4)*8+:8]<=data;
  if(index==7)begin index<=0;state<=DECODE;end else index<=index+1;
 end
 DECODE:begin
  left<=chunk_size;odd<=chunk_size[0];index<=0;
  if({1'b0,chunk_size}+{1'b0,consumed}>{1'b0,file_size})begin error<=3;state<=DRAIN;end
  else if(chunk_id==32'h20746d66)begin // "fmt "
   if(chunk_size<16)begin error<=2;state<=DRAIN;end else state<=FMT;
  end else if(chunk_id==32'h61746164)begin // "data"
   if(!seen_fmt||chunk_size==0)begin error<=2;state<=DRAIN;end
   else begin state<=PCM;sample_byte<=0;end
  end else if(chunk_size==0)state<=CHUNK;
  else state<=SKIP;
 end
 FMT:if(valid&&ready)begin
  case(index)
  0:encoding[7:0]<=data;1:encoding[15:8]<=data;
  2:channels[7:0]<=data;3:channels[15:8]<=data;
  4:sample_rate[7:0]<=data;5:sample_rate[15:8]<=data;6:sample_rate[23:16]<=data;7:sample_rate[31:24]<=data;
  8:byte_rate[7:0]<=data;9:byte_rate[15:8]<=data;10:byte_rate[23:16]<=data;11:byte_rate[31:24]<=data;
  12:block_align[7:0]<=data;13:block_align[15:8]<=data;14:bits[7:0]<=data;15:bits[15:8]<=data;
  endcase
  left<=left-1;if(index<16)index<=index+1;
  if(left==1)state<=CHECK_FMT;
 end
 CHECK_FMT:begin
  if(encoding!=1 || sample_rate!=48000 || (channels!=1&&channels!=2) ||
   (bits!=16&&bits!=24) ||
   (channels==1&&bits==16&&(block_align!=2||byte_rate!=96000)) ||
   (channels==2&&bits==16&&(block_align!=4||byte_rate!=192000)) ||
   (channels==1&&bits==24&&(block_align!=3||byte_rate!=144000)) ||
   (channels==2&&bits==24&&(block_align!=6||byte_rate!=288000)))begin error<=2;format_ok<=0;state<=DRAIN;end
  else begin seen_fmt<=1;format_ok<=1;index<=0;state<=odd?PAD:CHUNK;end
 end
 SKIP:if(valid&&ready)begin left<=left-1;if(left==1)state<=odd?PAD:CHUNK;end
 PAD:if(valid&&ready)begin state<=CHUNK;index<=0;end
 PCM:if(valid&&ready)begin
  left<=left-1;
  if(bits==16)begin
   case(sample_byte)
   0:begin b0<=data;sample_byte<=1;end
   1:begin
    if(channels==1)begin frame<={decoded,decoded};frame_valid<=1;sample_byte<=0;end
    else begin lsample<=decoded;sample_byte<=2;end
   end
   2:begin b0<=data;sample_byte<=3;end
   3:begin frame<={decoded,lsample};frame_valid<=1;sample_byte<=0;end
   endcase
  end else begin
   case(sample_byte)
   0:begin b0<=data;sample_byte<=1;end
   1:begin b1<=data;sample_byte<=2;end
   2:begin
    if(channels==1)begin frame<={decoded,decoded};frame_valid<=1;sample_byte<=0;end
    else begin lsample<=decoded;sample_byte<=3;end
   end
   3:begin b0<=data;sample_byte<=4;end
   4:begin b1<=data;sample_byte<=5;end
   5:begin frame<={decoded,lsample};frame_valid<=1;sample_byte<=0;end
   endcase
  end
  if(left==1)begin
   if((bits==16&&sample_byte!=(channels==1?1:3)) ||
      (bits==24&&sample_byte!=(channels==1?2:5)))begin error<=3;format_ok<=0;end
   state<=DRAIN;
  end
 end
 DRAIN:if(consumed>=file_size || eof)state<=FINISH;
 FINISH:if(!frame_valid)begin done<=1;state<=IDLE;end
 default:;
 endcase
 end end end
endmodule
