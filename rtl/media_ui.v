// Direct switches and single press keys; no chords or long presses.
module media_ui #(parameter CLK_HZ=25000000)(input clk,input rst,
 input [3:0] key_n,input [3:0] sw_level,input frame_tick,input transition_busy,
 output reg next_toggle,output auto_play,osd_enable,
 output reg signed [8:0] brightness,output reg [8:0] contrast,
 output [2:0] menu,output reg [1:0] visual_mode,transition_mode,
 output reg [7:0] fade_frames,output reg audio_mute);
 (*keep*) reg [7:0] sync0;(*keep*) reg [7:0] sync1;
 reg [7:0] stable;reg [19:0] counters[0:7];reg [3:0] pressed;
 reg [15:0] auto_frames;integer i;
 assign menu={1'b0,stable[5:4]};
 assign auto_play=stable[6];assign osd_enable=stable[7];
 always @(posedge clk or posedge rst)begin
 if(rst)begin sync0<=8'h0f;sync1<=8'h0f;stable<=8'h0f;pressed<=0;
 for(i=0;i<8;i=i+1)counters[i]<=0;end
 else begin
 sync0<={sw_level,key_n};sync1<=sync0;pressed<=0;
 for(i=0;i<8;i=i+1)begin
  if(sync1[i]==stable[i])counters[i]<=0;
  else if(counters[i]>=CLK_HZ/50-1)begin
   stable[i]<=sync1[i];counters[i]<=0;
   if(i<4&&!sync1[i])pressed[i]<=1;
  end else counters[i]<=counters[i]+1;
 end
 end end
 always @(posedge clk or posedge rst)begin
 if(rst)begin next_toggle<=0;brightness<=0;contrast<=128;visual_mode<=1;
 transition_mode<=0;fade_frames<=32;audio_mute<=0;auto_frames<=0;end
 else begin
 if(frame_tick)begin
  if(!auto_play||transition_busy)auto_frames<=0;
  else if(auto_frames==179)begin next_toggle<=~next_toggle;auto_frames<=0;end
  else auto_frames<=auto_frames+1;
 end
 if(pressed[1]&&!transition_busy)next_toggle<=~next_toggle;
 case(menu)
 0:begin
  if(pressed[2])audio_mute<=~audio_mute;
  if(pressed[3])visual_mode<=visual_mode==2?0:visual_mode+1;
 end
 1:begin
  if(pressed[2])brightness<=brightness>=112?127:brightness+16;
  if(pressed[3])brightness<=brightness<=-112?-128:brightness-16;
 end
 2:begin
  if(pressed[2])contrast<=contrast>=256?256:contrast+32;
  if(pressed[3])contrast<=contrast<=32?32:contrast-32;
 end
 3:begin
  if(pressed[2])transition_mode<=transition_mode==2?0:transition_mode+1;
  if(pressed[3])fade_frames<=fade_frames==16?32:fade_frames==32?64:16;
 end
 endcase
 end end
endmodule
