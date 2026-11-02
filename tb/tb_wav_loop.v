`timescale 1ns/1ps
module tb_wav_loop;
reg clk=0;always #5 clk=~clk;
reg rst=1,mounted=0,done=0,ok=0;reg [3:0] pe=0,fe=0;
wire op,available,failed;integer opens=0;
wav_file_control dut(clk,rst,mounted,3'd1,done,ok,pe,fe,op,available,failed);
always @(posedge clk)if(op)opens=opens+1;
initial begin
 #30;rst=0;mounted=1;wait(opens==1);@(negedge clk);ok=1;
 repeat(3)@(negedge clk);if(!available)$fatal(1,"valid WAV unavailable");
 done=1;@(negedge clk);done=0;ok=0;wait(opens==2);
 if(!available)$fatal(1,"source dropped while reopening WAV header");
 @(negedge clk);pe=2;repeat(10)@(negedge clk);
 if(!failed||available||opens!=2)$fatal(1,"invalid WAV not halted/fallback");
 $display("PASS WAV EOF automatic loop, sticky valid source and invalid-file fallback");$finish;
end
initial begin #10000;$fatal(1,"WAV loop timeout");end
endmodule
