`timescale 1ns/1ps
module tb_sector_arbiter;
reg clk=0;always #5 clk=~clk;
reg rst=1,ir=0,ar=0,urgent=1,sv=0,se=0;reg [31:0] ia=11,aa=22;reg [7:0] sd=0;
wire req;wire [31:0] addr;wire [7:0] id,ad;wire iv,ie,av,ae;
sd_sector_arbiter dut(clk,rst,ir,ia,ar,aa,req,addr,sd,sv,se,id,iv,ie,ad,av,ae,urgent);
integer i;
task transfer;input audio;input integer target;begin
 wait(req);#1;if(addr!=target)$fatal(1,"wrong sector owner");
 for(i=0;i<512;i=i+1)begin
  @(negedge clk);sv=1;sd=i;
  #1;if(audio?(!av||iv||ad!==sd):(!iv||av||id!==sd))$fatal(1,"sector bytes crossed owners");
  if(addr!=target)$fatal(1,"sector address changed mid-transfer");
 end
 @(negedge clk);sv=0;se=1;#1;if(audio?!ae:!ie)$fatal(1,"missing end");
 @(negedge clk);se=0;if(audio)ar=0;else ir=0;
 wait(!req);repeat(4)@(negedge clk);
end endtask
initial begin
 #30;rst=0;ir=1;ar=1;transfer(1,22);transfer(0,11);
 @(negedge clk);ir=1;ar=1;urgent=0;transfer(0,11);transfer(1,22);
 $display("PASS SD transaction locking, byte routing and low-water audio priority");$finish;
end
initial begin #100000;$fatal(1,"arbiter timeout");end
endmodule
