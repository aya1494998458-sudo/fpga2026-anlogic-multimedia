module reset_sync(input clk,input arst,output rst); (*keep*) reg [2:0] s; always @(posedge clk or posedge arst) if(arst)s<=7;else s<={s[1:0],1'b0}; assign rst=s[2];endmodule
