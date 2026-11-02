`timescale 1ns/1ps
module tb_wav_decoder;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0,valid=0,eof=0;reg [31:0] size;reg [7:0] data;
wire ready,fvalid,ok,done;wire [47:0] frame;wire [3:0] error;
reg [31:0] cycles=0;wire fready=cycles%13<8;
wav_pcm_decoder dut(clk,rst,start,size,data,valid,ready,eof,frame,fvalid,fready,ok,done,error);
reg [7:0] bytes[0:2047];reg [47:0] expected[0:76];
integer pos=0,n=0;reg run=0,finished=0;
always @(negedge clk)begin
 cycles=cycles+1;valid=0;eof=0;
 if(run&&pos<size&&cycles%5!=0)begin valid=1;data=bytes[pos];end
 if(run&&pos==size)eof=1;
end
always @(posedge clk)if(!rst&&run)begin
 if(valid&&ready)pos=pos+1;
 if(fvalid&&fready)begin
  if(frame!==expected[n])$fatal(1,"WAV sample%d got%h expected%h",n,frame,expected[n]);n=n+1;
 end
 if(done)finished=1;
end
task check;input [255:0] name;input integer len;input integer expected_error;reg [511:0] path;begin
 rst=1;run=0;start=0;repeat(4)@(negedge clk);
 $sformat(path,"assets/wav_tests/%0s.hex",name);$readmemh(path,bytes,0,len-1);
 $sformat(path,"assets/wav_tests/%0s_frames.hex",name);$readmemh(path,expected);
 pos=0;n=0;finished=0;size=len;rst=0;
 @(negedge clk);start=1;@(negedge clk);start=0;run=1;
 wait(finished);@(negedge clk);run=0;
 if(error!=expected_error)$fatal(1,"%s error%h expected%d",name,error,expected_error);
 if(expected_error==0 && (n!=77||!ok))$fatal(1,"%s incomplete PCM n%d",name,n);
 if(expected_error!=0 && n!=0)$fatal(1,"unsupported/truncated file played");
 $display("PASS WAV %0s frames=%0d error=%0d",name,n,error);
end endtask
initial begin
 check("mono16",238,0);check("stereo16",392,0);
 check("mono24",316,0);check("stereo24",546,0);
 check("bad_rate",392,2);check("bad_float",546,2);check("truncated",367,1);
 $finish;
end
initial begin #5000000;$fatal(1,"WAV decoder timeout state%d pos%d",dut.state,pos);end
endmodule
