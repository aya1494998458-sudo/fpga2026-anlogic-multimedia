`timescale 1ns/1ps
module tb_scaler_cases;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0;reg [31:0] fsize=0;reg [7:0] data=0;reg valid=0,eof=0;
wire ready,req,topdown,done;reg ack=0;wire [23:0] pixel;wire pv;
wire [3:0] error;wire [15:0] width,height;
reg [31:0] cycle=0;wire pready=cycle%11!=0;
bmp_bilinear_loader dut(clk,rst,start,fsize,data,valid,ready,eof,req,ack,pixel,pv,pready,topdown,done,error,width,height);
reg [7:0] bytes[0:921653];reg [23:0] expected[0:307199];
integer input_pos=0,output_pos=0;reg finished=0;reg running=0;
always @(negedge clk)begin
 cycle=cycle+1;ack=req;valid=0;eof=0;
 if(running&&input_pos<fsize&&cycle%5!=0)begin valid=1;data=bytes[input_pos];end
 if(running&&input_pos==fsize)eof=1;
end
always @(posedge clk)if(!rst&&running)begin
 if(valid&&ready)input_pos=input_pos+1;
 if(pv&&pready)begin
  if(pixel!==expected[output_pos])$fatal(1,"pixel %d got%h expected%h",output_pos,pixel,expected[output_pos]);
  output_pos=output_pos+1;
 end
 if(done)finished=1;
end
task run_case;input [255:0] name;input integer size;input integer w,h;input td,bad;
reg [511:0] path1,path2;begin
 rst=1;running=0;start=0;repeat(5)@(negedge clk);
 path1={"assets/",name,"_bytes.hex"};
 // $sformat avoids zero padding in packed-string concatenations.
 $sformat(path1,"assets/%0s_bytes.hex",name);$sformat(path2,"assets/%0s_expected.hex",name);
 $readmemh(path1,bytes,0,size-1);$readmemh(path2,expected);
 input_pos=0;output_pos=0;finished=0;fsize=size;rst=0;
 @(negedge clk);start=1;@(negedge clk);start=0;running=1;
 wait(finished);@(negedge clk);running=0;
 if(bad)begin if(error!=1||output_pos!=0)$fatal(1,"invalid BMP accepted");end
 else if(error||output_pos!=307200||width!=w||height!=h||topdown!=td)$fatal(1,"case failed %s",name);
 $display("PASS BMP %0s pixels=%0d top_down=%0d",name,output_pos,topdown);
end endtask
initial begin
 run_case("scale320",230454,320,240,0,0);
 run_case("scale640",921654,640,480,0,0);
 run_case("topdown",118,5,4,1,0);
 run_case("portrait",138,3,7,0,0);
 run_case("invalid",118,5,4,0,1);
 $finish;
end
initial begin #400000000;$fatal(1,"timeout");end
endmodule
