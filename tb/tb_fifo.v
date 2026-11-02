`timescale 1ns/1ps
module tb_fifo;
reg wc=0,rc=0;always #4 wc=~wc;always #7 rc=~rc;
reg rst=1,we=0,re=0;reg [31:0] din=0;wire [31:0] dout;
wire full,empty;wire [4:0] wcount,rcount;
async_pixel_fifo #(.WIDTH(32),.AW(4)) fifo(rst,wc,we,din,rc,re,dout,full,empty,wcount,rcount);
integer written=0,readn=0;reg expected_valid=0;reg [31:0] expected;
always @(negedge wc)begin
 we=0;if(!rst&&!full&&written<300)begin we=1;din=written*17+3;end
end
always @(posedge wc)if(we&&!full&&!rst)written=written+1;
always @(negedge rc)begin re=!rst&&!empty&&(readn%5!=4||$time%3!=0);end
always @(posedge rc)begin
 if(!rst&&re&&!empty)begin expected=readn*17+3;readn=readn+1;#1;
 if(dout!==expected)$fatal(1,"fifo order %d got %d expected%d",readn,dout,expected);
 end
 if(readn==300)begin $display("PASS asynchronous FIFO order, full and empty throttling");$finish;end
end
initial begin #30;rst=0;end
initial begin #100000;$fatal(1,"fifo timeout");end
endmodule
