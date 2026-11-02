`timescale 1ns/1ps
module tb_frame_memory;
reg mc=0,vc=0;always #6.5 mc=~mc;always #20 vc=~vc;
reg rst=1,vrst=1,refresh=0,read_req=0,read_en=0,check=0;
reg wreq=0,we=0,td=1;reg [1:0] bank=0;reg [31:0] wd=0;
wire ready,uf,of,ren,wen,rack,rfinish,wack,wfinish;
wire [20:0] ra,wa;wire [31:0] wdata;wire [3:0] dm;
wire [63:0] pair;reg [31:0] mem[0:63];
reg [9:0] rv=0;reg [31:0] pipe[0:9];
wire rdvalid=rv[9];wire [31:0] rddata=pipe[9];
frame_read_write #(.BURST_SIZE(8),.FRAME_WIDTH(8),.FRAME_HEIGHT(4)) dut(
 .write_top_down(td),.read_check(check),.read_rst(vrst),.write_ready(ready),.read_underflow(uf),.read_overflow(of),
 .rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(1'b0),
 .App_rd_en(ren),.App_rd_addr(ra),.Sdr_rd_en(rdvalid),.Sdr_rd_dout(rddata),
 .read_clk(vc),.read_req(read_req),.read_req_ack(rack),.read_finish(rfinish),
 .read_addr_0(21'd0),.read_addr_1(21'd32),.read_addr_2(21'd0),.read_addr_3(21'd32),
 .read_addr_index(2'd0),.read_len(21'd32),.read_en(read_en),.read_data(pair),
 .App_wr_en(wen),.App_wr_addr(wa),.App_wr_din(wdata),.App_wr_dm(dm),
 .write_clk(mc),.write_req(wreq),.write_req_ack(wack),.write_finish(wfinish),
 .write_addr_0(21'd0),.write_addr_1(21'd32),.write_addr_2(21'd0),.write_addr_3(21'd32),
 .write_addr_index(bank),.write_len(21'd32),.write_en(we),.write_data(wd));
integer i,j;reg [1:0] wg=0,rg=0;reg [20:0] wbase,rbase;
always @(posedge mc)begin
 rv<={rv[8:0],ren};for(j=9;j>0;j=j-1)pipe[j]<=pipe[j-1];
 if(wen&&ren)$fatal(1,"read/write overlap");
 if(refresh&&(wen||ren))$fatal(1,"transaction started during refresh");
 if(wen)begin
  // APUG011: only each four-word group's first address is accepted.
  if(wg==0)begin wbase=wa;if(wa[1:0]!=0)$fatal(1,"unaligned write group");end
  if(wa!=wbase+wg)$fatal(1,"illegal per-pixel jump within four-word write group");
  mem[wbase+wg]<=wdata;wg<=wg+1;
 end else begin if(wg!=0)$fatal(1,"partial write group");wg<=0;end
 if(ren)begin
  if(rg==0)begin rbase=ra;if(ra[1:0]!=0)$fatal(1,"unaligned read group");end
  if(ra!=rbase+rg)$fatal(1,"illegal read address group");
  pipe[0]<=mem[rbase+rg];rg<=rg+1;
 end else begin if(rg!=0)$fatal(1,"partial read group");rg<=0;end
end
task write_frame;input [1:0] b;begin
 @(negedge mc);bank=b;wreq=1;wait(wack);@(negedge mc);wreq=0;
 for(i=0;i<32;i=i+1)begin
  @(negedge mc);while(!ready)@(negedge mc);we=1;wd=(b==0?32'h10000000:32'h20000000)+i;
 end
 @(negedge mc);we=0;wait(wfinish);repeat(10)@(negedge mc);
end endtask
integer pixel=0;
initial begin
 #50;rst=0;vrst=0;write_frame(0);write_frame(1);
 for(i=0;i<32;i=i+1)begin
  if(mem[i]!==32'h10000000+i||mem[i+32]!==32'h20000000+i)$fatal(1,"SDRAM write ordering/ownership");
 end
 @(negedge vc);read_req=1;wait(rack);@(negedge vc);read_req=0;
 repeat(200)@(negedge mc);check=1;
 for(pixel=0;pixel<32;pixel=pixel+1)begin
  @(negedge vc);read_en=1;@(posedge vc);#1;
  if(pair!=={32'h20000000+pixel,32'h10000000+pixel})begin
   if(pair[31:0]!==32'h10000000+pixel||pair[63:32]!==32'h20000000+pixel)$fatal(1,"two-frame pairing pixel%d got%h",pixel,pair);
  end
 end
 @(negedge vc);read_en=0;
 if(uf||of)$fatal(1,"FIFO error");
 $display("PASS contiguous two-frame write/read under actual four-word address rule, serialized readers, 10-cycle response and paired pixels");$finish;
end
initial begin #500000;$fatal(1,"frame memory timeout");end
endmodule
