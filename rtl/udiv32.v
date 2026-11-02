// Iterative unsigned division; 32 clocks, no combinational divider.
module udiv32(input clk,input rst,input start,input [31:0] numerator,
 input [31:0] denominator,output reg done,output reg [31:0] quotient);
 reg [31:0] den,q;reg [32:0] rem;reg [5:0] count;
 wire [32:0] shifted={rem[31:0],q[31]};
 always @(posedge clk or posedge rst)begin
 if(rst)begin done<=0;count<=0;quotient<=0;q<=0;rem<=0;den<=0;end
 else begin done<=0;
 if(start && count==0)begin den<=denominator;q<=numerator;rem<=0;count<=32;end
 else if(count!=0)begin
  if(shifted>={1'b0,den})begin rem<=shifted-{1'b0,den};q<={q[30:0],1'b1};end
  else begin rem<=shifted;q<={q[30:0],1'b0};end
  count<=count-1;
  if(count==1)begin done<=1;quotient<={q[30:0],shifted>={1'b0,den}};end
 end end end
endmodule
