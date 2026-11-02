// Dual clock RAM FIFO, Gray pointers, registered read. Power-of-two depth.
module async_pixel_fifo #(parameter WIDTH=64,parameter AW=9)(
 input rst,input wclk,input we,input [WIDTH-1:0] din,
 input rclk,input re,output reg [WIDTH-1:0] dout,
 output full,output empty,output [AW:0] wcount,output [AW:0] rcount);
 wire wrst,rrst;
 reset_sync wreset(wclk,rst,wrst);
 reset_sync rreset(rclk,rst,rrst);
 reg [WIDTH-1:0] mem[0:(1<<AW)-1];
 reg [AW:0] wb,rb,wg,rg;reg wfull;
 (*keep*) reg [AW:0] rg1; (*keep*) reg [AW:0] rg2; (*keep*) reg [AW:0] wg1; (*keep*) reg [AW:0] wg2;
 wire [AW:0] wnext=wb+(we&&!full);
 wire [AW:0] wgray_next=(wnext>>1)^wnext;
 function [AW:0] ungray;input [AW:0] g;integer j;begin
 ungray[AW]=g[AW];for(j=AW-1;j>=0;j=j-1)ungray[j]=ungray[j+1]^g[j];end endfunction
 assign wcount=wb-ungray(rg2);assign rcount=ungray(wg2)-rb;
 assign full=wrst || wfull;assign empty=rrst || rg==wg2;
 always @(posedge wclk or posedge wrst)begin
 if(wrst)begin wb<=0;wg<=0;rg1<=0;rg2<=0;wfull<=0;end
 else begin rg1<=rg;rg2<=rg1;
 wfull<=wgray_next=={~rg2[AW:AW-1],rg2[AW-2:0]};
 if(we&&!full)begin mem[wb[AW-1:0]]<=din;wb<=wnext;wg<=wgray_next;end end end
 always @(posedge rclk or posedge rrst)begin
 if(rrst)begin rb<=0;rg<=0;wg1<=0;wg2<=0;dout<=0;end
 else begin wg1<=wg;wg2<=wg1;
 if(re&&!empty)begin dout<=mem[rb[AW-1:0]];rb<=rb+1;rg<=((rb+1)>>1)^(rb+1);end end end
endmodule
