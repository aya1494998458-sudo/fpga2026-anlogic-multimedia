`timescale 1ns/1ps
module tb_storage_scaler;
reg clk=0;always #5 clk=~clk;
reg rst=1,sdready=0,openfile=0;
wire mounted;wire [2:0] count;wire [3:0] ferr,lerr;
wire [31:0] fsize;wire fstart;wire [7:0] b;wire bv,br,eof,req;
wire [31:0] addr;reg [7:0] sdbyte;reg sdv=0,sde=0;
wire wreq;reg wack=0;wire [23:0] pixel;wire pv,topdown,done;wire [15:0] width,height;
reg [31:0] cycles=0;wire pready=cycles%7!=0;
fat32_reader fs(clk,rst,sdready,openfile,2'd0,mounted,count,ferr,fsize,fstart,b,bv,br,eof,req,addr,sdbyte,sdv,sde);
bmp_bilinear_loader sc(clk,rst,fstart,fsize,b,bv,br,eof,wreq,wack,pixel,pv,pready,topdown,done,lerr,width,height);
reg [7:0] disk[0:8191];reg [23:0] expected[0:307199];
integer j=0;integer lba=0;reg [1:0] state=0;integer pcount=0;
always @(negedge clk)begin
 cycles<=cycles+1;sdv<=0;sde<=0;wack<=wreq;
 if(!rst)case(state)
 0:if(req)begin lba=addr;j=0;state=1;end
 1:if(cycles%3!=0)begin sdbyte<=disk[lba*512+j];sdv<=1;if(j==511)state=2;else j=j+1;end
 2:begin sde<=1;state=3;end
 3:if(!req)state=0;
 endcase
end
always @(posedge clk)begin
 if(pv&&pready)begin
  if(pixel!==expected[pcount])$fatal(1,"pixel %d got %h expected %h",pcount,pixel,expected[pcount]);
  pcount=pcount+1;
 end
 if(done)begin
  if(ferr||lerr||pcount!=307200||width!=37||height!=7||topdown)$fatal(1,"metadata/end pixels=%d err=%h/%h",pcount,ferr,lerr);
  $display("PASS FAT32 MBR + fragmented root and file, BMP row padding, 307200 bilinear letterbox pixels under backpressure");$finish;
 end
end
initial begin
 $readmemh("assets/fat32_fragmented.hex",disk);$readmemh("assets/scaler_expected.hex",expected);
 #35;rst=0;sdready=1;wait(mounted);if(count!=1||ferr)$fatal(1,"mount failed");
 @(negedge clk);openfile=1;@(negedge clk);openfile=0;
end
initial begin #1000000;$display("DEBUG width=%d height=%d lx=%d row=%d bank=%d consumed=%d phase=%d fh=%d fw=%d lo=%d",width,height,sc.lx,sc.load_row,sc.bank,sc.consumed,sc.byte_phase,sc.fh,sc.fw,sc.lo_row); #79000000;$fatal(1,"timeout fs=%d scaler=%d count=%d",fs.state,sc.state,pcount);end
endmodule

