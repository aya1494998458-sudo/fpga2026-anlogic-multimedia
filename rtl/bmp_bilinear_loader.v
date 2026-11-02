// 24-bit BI_RGB BMP, 2..640 x 2..480. Two alternating source line buffers.
// Hardware aspect fit + Q16 coordinate mapping + bilinear interpolation.
// Output is a full 640x480 frame including letterbox pixels, in BMP row order.
module bmp_bilinear_loader(input clk,input rst,input start,input [31:0] file_size,
 input [7:0] data,input valid,output ready,input eof,
 output reg write_req,input write_ack,output [23:0] pixel,
 output pixel_valid,input pixel_ready,output reg top_down,
 output reg done,output reg [3:0] error,
 output reg [15:0] source_width,source_height);
 localparam HEADER=1,CHECK=2,DIV_FIT=3,WAIT_FIT=4,DIV_X=5,WAIT_X=6,
 DIV_Y=7,WAIT_Y=8,REQUEST=9,SKIP=10,LINE=11,PAD=12,
 ROW=13,FETCH=14,HORIZ=15,VERT=16,SEND=17,BLACK=18,DRAIN=19,IDLE=0;
 reg [4:0] state,after_line;reg [7:0] header[0:53];reg [5:0] hp;
 reg [31:0] offset,consumed,row_stride,step_x,step_y,ax,ay;
 reg [9:0] fw,fh,ox,oy,dx,dy,lx;reg [8:0] lo_row,load_row;
 reg bank,fill_bank;reg [1:0] byte_phase;reg [23:0] rgb;
 reg [7:0] blue,green;reg [1:0] padding,pad_left;
 reg [23:0] line0[0:639],line1[0:639];
 reg [9:0] line_addr; reg [23:0] q0,q1;
 always @(posedge clk)begin
  q0<=line0[line_addr];q1<=line1[line_addr];
  if(!rst && state==LINE && valid && byte_phase==2)begin
   if(fill_bank)line1[lx]<={data,green,blue};else line0[lx]<={data,green,blue};
  end
 end
 reg [23:0] p00,p01,p10,p11;reg [16:0] hx0[0:2],hx1[0:2];
 reg [25:0] vy0[0:2],vy1[0:2],vsum[0:2];
 reg [7:0] fx,fy;reg [9:0] src_x;reg [9:0] src_x1;
 reg div_start;reg [31:0] num,den;wire div_done;wire [31:0] quot;
 udiv32 divider(clk,rst,div_start,num,den,div_done,quot);
 function [31:0] h32;input integer a;begin h32={header[a+3],header[a+2],header[a+1],header[a]};end endfunction
 assign ready=state==HEADER||(state==SKIP && consumed<offset)||state==LINE||state==PAD||state==DRAIN;
 assign pixel=rgb;assign pixel_valid=state==SEND||state==BLACK;
 wire [31:0] in_w={header[21],header[20],header[19],header[18]}, raw_h={header[25],header[24],header[23],header[22]};
 wire [31:0] in_h=raw_h[31] ? (~raw_h+1'b1):raw_h;
 wire [31:0] stride=(in_w*3+3)&32'hfffffffc;
 reg [31:0] header_w,header_h;reg [9:0] small_w,small_h;reg [19:0] aspect_w,aspect_h;
 reg fit_by_width;reg format_bad;reg [23:0] payload;reg [31:0] file_end;
 wire active=dx>=ox && dx<ox+fw && dy>=oy && dy<oy+fh;
 integer c;
 always @(posedge clk or posedge rst)begin
 if(rst)begin state<=IDLE;hp<=0;consumed<=0;write_req<=0;done<=0;error<=0;
 source_width<=0;source_height<=0;top_down<=0;div_start<=0;rgb<=0;
 dx<=0;dy<=0;ax<=0;ay<=0;lo_row<=0;load_row<=0;bank<=0;fill_bank<=0;end
 else begin done<=0;div_start<=0;
 if(valid&&ready)consumed<=consumed+1;
 if(start)begin state<=HEADER;hp<=0;consumed<=0;error<=0;write_req<=0;end
 else case(state)
 HEADER:if(valid)begin header[hp]<=data;if(hp==53)state<=CHECK;else hp<=hp+1;end
 CHECK:begin
  format_bad<=(header[0]!="B"||header[1]!="M"||h32(14)!=40||{header[27],header[26]}!=1 ||
   {header[29],header[28]}!=24||h32(30)!=0||in_w<2||in_w>640||in_h<2||in_h>480||
   h32(10)<54);
  payload<=stride[11:0]*in_h[8:0];offset<=h32(10);header_w<=in_w;header_h<=in_h;state<=23;
 end
 23:begin file_end<=offset+payload;small_w<=header_w[9:0];small_h<=header_h[9:0];state<=24;end
 24:begin
  if(format_bad || file_end>file_size)begin error<=1;state<=DRAIN;end
  else begin
   source_width<=small_w;source_height<=small_h;top_down<=raw_h[31];
   offset<=h32(10);row_stride<=stride;padding<=stride-in_w*3;
   aspect_w<=small_w*10'd480;aspect_h<=small_h*10'd640;state<=25;
  end
 end
 25:begin
  fit_by_width<=aspect_w>=aspect_h;
  if(aspect_w>=aspect_h)begin fw<=640;num<=aspect_h;den<=small_w;end
  else begin fh<=480;num<=aspect_w;den<=small_h;end
  state<=DIV_FIT;
 end
 DIV_FIT:begin div_start<=1;state<=WAIT_FIT;end
 WAIT_FIT:if(div_done)begin
  if(fit_by_width)fh<=quot<2?2:quot[9:0];else fw<=quot<2?2:quot[9:0];
  state<=DIV_X;
 end
 DIV_X:begin num<=(source_width-1)<<16;den<=fw-1;state<=WAIT_X;div_start<=1;end
 WAIT_X:if(div_done)begin step_x<=quot;state<=DIV_Y;end
 DIV_Y:begin num<=(source_height-1)<<16;den<=fh-1;ox<=(640-fw)>>1;oy<=(480-fh)>>1;
  state<=WAIT_Y;div_start<=1;end
 WAIT_Y:if(div_done)begin step_y<=quot;state<=REQUEST;write_req<=1;end
 REQUEST:if(write_ack)begin write_req<=0;dx<=0;dy<=0;ax<=0;ay<=0;
  bank<=0;fill_bank<=0;load_row<=0;lo_row<=0;lx<=0;byte_phase<=0;state<=SKIP;end
 SKIP:if(consumed>=offset)state<=LINE;
 LINE:if(valid)begin
  case(byte_phase)
   0:begin blue<=data;byte_phase<=1;end
   1:begin green<=data;byte_phase<=2;end
   2:begin

    byte_phase<=0;
    if(lx==source_width-1)begin
     lx<=0;pad_left<=padding;
     if(padding!=0)state<=PAD;
     else if(load_row==0)begin load_row<=1;fill_bank<=1;end
     else state<=ROW;
    end else lx<=lx+1;
   end
  endcase
 end
 PAD:if(valid)begin
  if(pad_left==1)begin
   if(load_row==0)begin load_row<=1;fill_bank<=1;state<=LINE;end
   else state<=ROW;
  end else pad_left<=pad_left-1;
 end
 ROW:begin
  if(dy==480)begin state<=DRAIN;end
  else if(!active)begin rgb<=0;state<=BLACK;end
  else if((ay>>16)>lo_row)begin
   lo_row<=lo_row+1;bank<=~bank;load_row<=lo_row+2;fill_bank<=bank;
   if(lo_row+2<source_height)begin state<=LINE;lx<=0;byte_phase<=0;end
  end else begin
   src_x<=ax>>16;src_x1<=(ax>>16)>=source_width-1 ? source_width-1:(ax>>16)+1;
   fx<=ax[15:8];fy<=lo_row==source_height-1?0:ay[15:8];line_addr<=ax>>16;state<=20;
  end
 end
 20:state<=FETCH;
 FETCH:begin
  if(bank)begin p00<=q1;p10<=q0;end else begin p00<=q0;p10<=q1;end
  line_addr<=src_x1;state<=21;
 end
 21:state<=22;
 22:begin
  if(bank)begin p01<=q1;p11<=q0;end else begin p01<=q0;p11<=q1;end
  state<=HORIZ;
 end
 HORIZ:begin
  for(c=0;c<3;c=c+1)begin
   hx0[c]<=p00[c*8+:8]*(9'd256-{1'b0,fx})+p01[c*8+:8]*fx;
   hx1[c]<=p10[c*8+:8]*(9'd256-{1'b0,fx})+p11[c*8+:8]*fx;
  end
  state<=VERT;
 end
 VERT:begin
  for(c=0;c<3;c=c+1)begin vy0[c]<=hx0[c]*(9'd256-{1'b0,fy});vy1[c]<=hx1[c]*fy;end
  state<=26;
 end
 26:begin for(c=0;c<3;c=c+1)vsum[c]<=vy0[c]+vy1[c]+26'd32768;state<=27;end
 27:begin for(c=0;c<3;c=c+1)rgb[c*8+:8]<=vsum[c][23:16];state<=SEND;end
 SEND,BLACK:if(pixel_ready)begin
  if(active)ax<=ax+step_x;
  if(dx==639)begin dx<=0;dy<=dy+1;ax<=0;
   if(dy>=oy && dy<oy+fh)ay<=ay+step_y;
  end else dx<=dx+1;
  state<=ROW;
 end
 DRAIN:if(eof || consumed>=file_size)begin done<=1;state<=IDLE;end
 default:;
 endcase
 end end
endmodule

