// True 64-point, 16-bin DFT of PCM decimated by 16 (no anti-alias filter).
// Frequency axis is 46.9 Hz/bin at nominal 48 kHz. L1 complex magnitude
// approximates spectral amplitude. Waveform uses the same real PCM samples.
module audio_visualizer(input clk,input rst,input pcm_valid,input signed [23:0] pcm,
 input [9:0] x,input [9:0] y,input [1:0] mode,output reg ink,
 output reg [23:0] color,output reg [7:0] peak);
 reg [3:0] decim;reg [8:0] wp;reg wb,shown,have_wave;
 reg signed [7:0] wave[0:1023];reg signed [11:0] sample;
 reg [5:0] n;reg [3:0] k;reg calculating;
 reg signed [27:0] real_acc[0:15],imag_acc[0:15];
 reg [7:0] magnitude[0:15];
 wire [5:0] phase=n*(k+5'd1);
 wire signed [7:0] cs,sn;
 dft_coeff coeff(phase,cs,sn);
 wire signed [20:0] pr=sample*cs,pi=sample*sn;
 wire signed [28:0] tr=real_acc[k]+pr,ti=imag_acc[k]-pi;
 wire [28:0] ar=tr[28]?-tr:tr,ai=ti[28]?-ti:ti;
 wire [29:0] mag=(ar+{1'b0,ai})>>17;
 wire signed [7:0] ws=wave[{shown,x[8:0]}];
 wire signed [10:0] wy=11'sd400-{{3{ws[7]}},ws};
 integer i;
 always @(posedge clk or posedge rst)begin
 if(rst)begin decim<=0;wp<=0;wb<=0;shown<=0;have_wave<=0;n<=0;k<=0;
 calculating<=0;peak<=0;sample<=0;
 for(i=0;i<16;i=i+1)begin real_acc[i]<=0;imag_acc[i]<=0;magnitude[i]<=0;end
 end else begin
 if(pcm_valid)begin
  decim<=decim+1;
  if(decim==0&&!calculating)begin
   sample<=pcm[23:12];calculating<=1;k<=0;
   wave[{wb,wp}]<=pcm[23:16];wp<=wp+1;
   if(wp==511)begin shown<=wb;wb<=~wb;have_wave<=1;end
   if(pcm[23])peak<=(-pcm)>>>16;else peak<=pcm[23:16];
  end
 end
 if(calculating)begin
  if(n==63)begin magnitude[k]<=mag>127?127:mag[7:0];real_acc[k]<=0;imag_acc[k]<=0;end
  else begin real_acc[k]<=tr;imag_acc[k]<=ti;end
  if(k==15)begin calculating<=0;n<=n+1;end else k<=k+1;
 end
 end end
 always @*begin
 ink=0;color=24'h20ff80;
 if(x<512 && y>=320 && y<476)begin
  if(mode==1 && have_wave && ($signed({1'b0,y})>=wy-1)&&($signed({1'b0,y})<=wy+1))ink=1;
  if(mode==2 && x[4:0]<28 && y>=475-magnitude[x[8:5]])begin ink=1;color={x[8:5],4'hf,8'hc0,8'h20};end
  if(mode!=0 && (y==400||y==475))begin ink=1;color=24'h305060;end
 end
 end
endmodule
