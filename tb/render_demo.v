`timescale 1ns/1ps
// This writes actual video_effects HDL output to PPM. It is not a board photo.
module render_demo;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0;reg [63:0] pair=0;
wire [23:0] rgb;wire oh,ov,od,frame;
video_effects dut(clk,rst,hs,vs,de,pair,1'b1,1'b0,1'b1,9'd96,2'd0,
 9'sd16,9'd160,1'b1,1'b1,3'd1,2'd2,16'd320,16'd240,2'd0,1'b0,24'd0,4'd0,rgb,oh,ov,od,frame);
integer fd,n=0,x,y,k;reg [7:0] r,g,b;
always @(negedge clk)if(od)begin $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);n=n+1;end
initial begin
 fd=$fopen("reports/hdl_preview.ppm","wb");$fwrite(fd,"P6\n640 480\n255\n");
 #30;rst=0;@(negedge clk);vs=1;repeat(8)@(negedge clk);vs=0;
 for(y=0;y<480;y=y+1)begin
  for(x=0;x<640;x=x+1)begin
   @(negedge clk);de=1;r=x*255/639;g=y*255/479;b=8'd96;
   pair={{b,r,g,8'd0},{r,g,b,8'd0}};
  end
  @(negedge clk);de=0;repeat(159)@(negedge clk);
 end
 repeat(8)@(negedge clk);$fclose(fd);
 if(n!=307200)$fatal(1,"render output pixel count %d",n);
 $display("PASS HDL-rendered 640x480 output preview");$finish;
end
endmodule
