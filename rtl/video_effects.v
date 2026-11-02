// Three pixel pipeline stages: true two-picture mix, signed enhancement,
// then real PCM visualization and ROM-text OSD. Syncs travel with the pixels.
module video_effects #(parameter [23:0] OSD_FG=24'hffe080,
 parameter [23:0] OSD_BG=24'h000000,parameter [8:0] PANEL_ALPHA=192)
 (input clk,input rst,input hs,input vs,input de,
 input [63:0] pair,input display_valid,input old_bank,input new_bank,
 input [8:0] alpha,input [1:0] transition_mode,
 input signed [8:0] brightness,input [8:0] contrast,input osd_enable,
 input auto_play,input [2:0] menu,input [1:0] file_index,
 input [15:0] source_width,source_height,input [1:0] visual_mode,
 input pcm_valid,input [23:0] pcm,input [3:0] error,
 output [23:0] out_rgb,output out_hs,out_vs,out_de,output frame_tick);
 reg vs_d,de_d;reg [9:0] x,y;reg [9:0] px0,py0,px1,py1;
 reg [23:0] mixed,adjusted,result;reg [2:0] hd,vd,dd;
 reg signed [8:0] bri;reg [8:0] con;reg [9:0] scroll;
 wire [23:0] a=old_bank?pair[63:40]:pair[31:8];
 wire [23:0] b=new_bank?pair[63:40]:pair[31:8];
 reg [7:0] ch;wire glyph;reg [9:0] tx,ty;reg panel;
 wire wave_ink;wire [23:0] wave_color;wire [7:0] peak;
 audio_visualizer av(clk,rst,pcm_valid,pcm,px1,py1,visual_mode,wave_ink,wave_color,peak);
 font_rom font(ch,ty[3:1],tx[3:1],glyph);
 assign frame_tick=vs && !vs_d;
 assign out_rgb=result;assign out_hs=hd[2];assign out_vs=vd[2];assign out_de=dd[2];
 function [7:0] digit;input [3:0] value;begin digit=value<10?"0"+value:"A"+value-10;end endfunction
 function [7:0] enhance;input [7:0] v;input signed [8:0] br;input [8:0] co;
 reg signed [19:0] z;begin
 z=($signed({1'b0,v})-20'sd128)*$signed({1'b0,co});
 z=(z>>>7)+20'sd128+br;enhance=z<0?0:z>255?255:z[7:0];end endfunction
 reg [3:0] w100,w10,w1,h100,h10,h1,b100,b10,b1,c100,c10,c1,p100,p10,p1;
 wire [8:0] abs_bri=brightness[8]?-brightness:brightness;
 always @(posedge clk)if(frame_tick)begin
  w100<=source_width[9:0]/10'd100;w10<=(source_width[9:0]/10'd10)%10;w1<=source_width[9:0]%10;
  h100<=source_height[8:0]/9'd100;h10<=(source_height[8:0]/9'd10)%10;h1<=source_height[8:0]%10;
  b100<=abs_bri/9'd100;b10<=(abs_bri/9'd10)%10;b1<=abs_bri%10;
  c100<=contrast/9'd100;c10<=(contrast/9'd10)%10;c1<=contrast%10;
  p100<=peak/8'd100;p10<=(peak/8'd10)%10;p1<=peak%10;
 end
 integer c;
 always @(posedge clk or posedge rst)begin
 if(rst)begin vs_d<=0;de_d<=0;x<=0;y<=0;px0<=0;py0<=0;px1<=0;py1<=0;
 mixed<=0;adjusted<=0;result<=0;hd<=0;vd<=0;dd<=0;bri<=0;con<=128;scroll<=0;end
 else begin
 vs_d<=vs;de_d<=de;hd<={hd[1:0],hs};vd<={vd[1:0],vs};dd<={dd[1:0],de};
 if(frame_tick)begin x<=0;y<=0;bri<=brightness;con<=contrast;scroll<=scroll==767?0:scroll+1;end
 else if(de)begin if(x==639)x<=0;else x<=x+1;end
 else if(de_d)begin y<=y+1;x<=0;end
 px0<=x;py0<=y;px1<=px0;py1<=py0;
 for(c=0;c<3;c=c+1)begin
  if(!display_valid)mixed[c*8+:8]<=0;
  else if(transition_mode==1)mixed[c*8+:8]<=x*2<alpha*5?b[c*8+:8]:a[c*8+:8];
  else mixed[c*8+:8]<=(a[c*8+:8]*(9'd256-alpha)+b[c*8+:8]*alpha+32'd128)>>8;
  adjusted[c*8+:8]<=enhance(mixed[c*8+:8],bri,con);
 end
 if(!dd[1])result<=0;
 else if(osd_enable && panel && glyph)result<=OSD_FG;
 else if(osd_enable && panel)begin
  for(c=0;c<3;c=c+1)result[c*8+:8]<=(adjusted[c*8+:8]*(9'd256-PANEL_ALPHA)+OSD_BG[c*8+:8]*PANEL_ALPHA+32'd128)>>8;
 end
 else if(wave_ink)result<=wave_color;
 else result<=adjusted;
 end end
 reg [6:0] ci;
 always @*begin
 tx=px1;ty=py1;panel=0;ch=" ";ci=0;
 if(py1<32 && px1<640)begin
 panel=1;ci=px1>>4;
 if(py1<16)case(ci)
 0:ch="F";1:ch="P";2:ch="G";3:ch="A";5:ch="M";6:ch="E";7:ch="D";8:ch="I";9:ch="A";
 12:ch="I";13:ch="M";14:ch="G";15:ch=digit({2'b0,file_index}+1);
 18:ch=auto_play?"A":"M";19:ch=auto_play?"U":"A";20:ch=auto_play?"T":"N";21:ch=auto_play?"O":"U";
 24:ch="B";25:ch=bri[8]?"-":"+";
 26:ch=digit(b100);27:ch=digit(b10);28:ch=digit(b1);
 31:ch="C";32:ch=digit(c100);33:ch=digit(c10);34:ch=digit(c1);
 37:ch="E";38:ch=digit(error);
 endcase
 else case(ci)
 0:ch="P";1:ch="A";2:ch="G";3:ch="E";5:ch=digit({1'b0,menu});
 8:ch="S";9:ch="R";10:ch="C";
 12:ch=digit(w100);13:ch=digit(w10);14:ch=digit(w1);15:ch="X";
 16:ch=digit(h100);17:ch=digit(h10);18:ch=digit(h1);
 21:ch="V";22:ch="I";23:ch="S";25:ch=digit({2'b0,visual_mode});
 28:ch="P";29:ch="E";30:ch="A";31:ch="K";
 33:ch=digit(p100);34:ch=digit(p10);35:ch=digit(p1);
 endcase
 end else if(py1>=288 && py1<304)begin
 panel=1;tx=px1+scroll;ty=py1-288;ci=(px1+scroll)>>4;
 case(ci)
 0:ch="A";1:ch="N";2:ch="L";3:ch="O";4:ch="G";5:ch="I";6:ch="C";
 8:ch="F";9:ch="P";10:ch="G";11:ch="A";
 13:ch="L";14:ch="I";15:ch="V";16:ch="E";
 18:ch="M";19:ch="E";20:ch="D";21:ch="I";22:ch="A";
 24:ch="C";25:ch="O";26:ch="N";27:ch="T";28:ch="E";29:ch="S";30:ch="T";
 32:ch="2";33:ch="0";34:ch="2";35:ch="6";
 endcase
 end
 end
endmodule
