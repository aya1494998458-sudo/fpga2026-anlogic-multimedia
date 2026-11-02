`timescale 1ns/1ps
module tb_frame_writer;
reg clk=0;always #5 clk=~clk;
reg rst=1,td=0,req=0;wire busy,en,ack,finish,clear;
wire [20:0] addr;reg [1:0] bank=1;integer n=0;integer expected;reg running=0;
frame_fifo_write #(.FRAME_WIDTH(4),.FRAME_HEIGHT(3),.BURST_SIZE(4),.BURST_BITS(4)) dut(
 .write_top_down(td),.rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),
 .Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.App_rd_busy(1'b0),.O_wr_busy(busy),
 .App_wr_en(en),.App_wr_addr(addr),.write_req(req),.write_req_ack(ack),.write_finish(finish),
 .write_addr_0(21'd0),.write_addr_1(21'd12),.write_addr_2(21'd0),.write_addr_3(21'd12),
 .write_addr_index(bank),.write_len(21'd12),.fifo_aclr(clear),.rdusedw(10'd511));
always @(posedge clk)if(running&&en)begin
 expected=(td?(n/4):(2-n/4))*4+(n%4)+(bank==1?12:0);
 if(addr!==expected)$fatal(1,"contiguous frame addr %d got%d expected%d",n,addr,expected);
 n=n+1;
end
task run_frame;input top;input [1:0] bufindex;begin
 @(negedge clk);td=top;bank=bufindex;n=0;req=1;running=1;
 wait(ack);@(negedge clk);req=0;wait(finish);@(negedge clk);running=0;
 if(n!=12)$fatal(1,"frame word count %d",n);
 repeat(4)@(negedge clk);
end endtask
initial begin #30;rst=0;run_frame(0,1);run_frame(1,0);
 $display("PASS SDRAM contiguous-bank addresses, bottom-up reversal, top-down and burst completion");$finish;end
initial begin #100000;$fatal(1,"writer timeout");end
endmodule
