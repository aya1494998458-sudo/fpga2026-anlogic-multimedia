// Test-only show-ahead FIFO behavioral model. Not referenced by the TD project.
module wfifo_32_32_512(input rst,input clkw,input clkr,input we,input re,
 input [31:0] di,output [31:0] dout,output empty_flag,full_flag,
 output [8:0] wrusedw,rdusedw);
reg [31:0] mem[0:511];reg [9:0] w,r;
wire [9:0] count=w-r;
assign wrusedw=count[8:0];assign rdusedw=count[8:0];
assign full_flag=count==511;assign empty_flag=w==r;assign dout=mem[r[8:0]];
always @(posedge clkw or posedge rst)if(rst)w<=0;else if(we&&!full_flag)begin mem[w[8:0]]<=di;w<=w+1;end
always @(posedge clkr or posedge rst)if(rst)r<=0;else if(re&&!empty_flag)r<=r+1;
endmodule
