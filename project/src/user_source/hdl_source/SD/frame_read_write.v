`timescale 1ns/1ps
module frame_read_write
#
(
	parameter MEM_DATA_BITS          = 32,
	parameter READ_DATA_BITS         = 64,
	parameter WRITE_DATA_BITS        = 32,
	parameter ADDR_BITS              = 21,
	parameter BURST_BITS             = 9,//
	parameter BURST_SIZE             = 128,
	parameter WRITE_V_FLIP           = 1,      // 1: vertical flip when writing TF/BMP frame into SDRAM
	parameter FRAME_WIDTH            = 640,
	parameter FRAME_HEIGHT           = 480
) 
(
	input write_top_down,
 input read_check,
 input read_rst,
 output write_ready,
 output reg read_underflow,
 output reg read_overflow,
	input                            rst,                  
	input                            mem_clk,                    // external memory controller user interface clock
	input							 Sdr_init_done,
	input							 Sdr_init_ref_vld,
    input							 Sdr_busy,
	
    /*
    output                           rd_burst_req,               // to external memory controller,send out a burst read request
	output[BURST_BITS - 1:0]         rd_burst_len,               // to external memory controller,data length of the burst read request, not bytes
	output[ADDR_BITS - 1:0]          rd_burst_addr,              // to external memory controller,base address of the burst read request 
	input                            rd_burst_data_valid,        // from external memory controller,read data valid 
	input[MEM_DATA_BITS - 1:0]       rd_burst_data,              // from external memory controller,read request data
	input                            rd_burst_finish,            // from external memory controller,burst read finish
	*/
	output							 App_rd_en,
	output[ADDR_BITS - 1:0]			 App_rd_addr,
	input							 Sdr_rd_en,					 //read_data_valid
	input[MEM_DATA_BITS - 1:0]		 Sdr_rd_dout,
	
	input                            read_clk,                   // data read module clock
	input                            read_req,                   // data read module read request,keep '1' until read_req_ack = '1'
	output                           read_req_ack,               // data read module read request response
	output                           read_finish,                // data read module read request finish
	input[ADDR_BITS - 1:0]           read_addr_0,                // data read module read request base address 0, used when read_addr_index = 0
	input[ADDR_BITS - 1:0]           read_addr_1,                // data read module read request base address 1, used when read_addr_index = 1
	input[ADDR_BITS - 1:0]           read_addr_2,                // data read module read request base address 1, used when read_addr_index = 2
	input[ADDR_BITS - 1:0]           read_addr_3,                // data read module read request base address 1, used when read_addr_index = 3
	input[1:0]                       read_addr_index,            // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
	input[ADDR_BITS - 1:0]           read_len,                   // data read module read request data length
	input                            read_en,                    // data read module read request for one data, read_data valid next clock
	output[READ_DATA_BITS  - 1:0]    read_data,                  // read data
	/*
	output                           wr_burst_req,               // to external memory controller,send out a burst write request
	output[BURST_BITS - 1:0]         wr_burst_len,               // to external memory controller,data length of the burst write request, not bytes
	output[ADDR_BITS - 1:0]          wr_burst_addr,              // to external memory controller,base address of the burst write request 
	input                            wr_burst_data_req,          // from external memory controller,write data request ,before data 1 clock
	output[MEM_DATA_BITS - 1:0]      wr_burst_data,              // to external memory controller,write data
	input                            wr_burst_finish,            // from external memory controller,burst write finish
	*/
	output							 App_wr_en,
	output[ADDR_BITS - 1:0]			 App_wr_addr,
	output[MEM_DATA_BITS - 1:0]	 App_wr_din,
	output[3:0]						 App_wr_dm,
	
	//
	input                            write_clk,                  // data write module clock
	input                            write_req,                  // data write module write request,keep '1' until read_req_ack = '1'
	output                           write_req_ack,              // data write module write request response
	output                           write_finish,               // data write module write request finish
	input[ADDR_BITS - 1:0]           write_addr_0,               // data write module write request base address 0, used when write_addr_index = 0
	input[ADDR_BITS - 1:0]           write_addr_1,               // data write module write request base address 1, used when write_addr_index = 1
	input[ADDR_BITS - 1:0]           write_addr_2,               // data write module write request base address 1, used when write_addr_index = 2
	input[ADDR_BITS - 1:0]           write_addr_3,               // data write module write request base address 1, used when write_addr_index = 3
	input[1:0]                       write_addr_index,           // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
	input[ADDR_BITS - 1:0]           write_len,                  // data write module write request data length
	input                            write_en,                   // data write module write request for one data
	input[WRITE_DATA_BITS - 1:0]     write_data                 // write data

);
// Two contiguous frames, required by APUG011 four-word address grouping.
wire [9:0] rdusedw0,rdusedw1;
wire [BURST_BITS-1:0] rdusedw;
wire write_fifo_aclr,write_full;
wire O_wr_busy,read_busy0,read_busy1;
wire want0,want1,ack0,ack1,finish0,finish1;
wire en0,en1,clr0,clr1;
wire [ADDR_BITS-1:0] addr0,addr1;
wire [MEM_DATA_BITS-1:0] data0,data1;
wire full0,full1,empty0,empty1;
wire [9:0] unused0,unused1;
reg turn,last_owner,previous_busy;
wire any_read_busy=read_busy0|read_busy1;
wire choose0=read_busy0 || (!read_busy1 && want0 && (!want1 || !turn));
wire choose1=read_busy1 || (!read_busy0 && want1 && (!want0 || turn));
wire App_rd_busy=any_read_busy;
assign write_ready=!write_full&&!write_fifo_aclr&&!rst;
assign App_wr_dm=4'b0;
assign App_rd_en=en0|en1;
assign App_rd_addr=en1?addr1:addr0;
assign read_req_ack=ack0&ack1;
assign read_finish=finish0&finish1;
assign read_data={data1,data0};
always @(posedge mem_clk or posedge rst)begin
 if(rst)begin turn<=0;last_owner<=0;previous_busy<=0;end
 else begin
  previous_busy<=any_read_busy;
  if(read_busy0)last_owner<=0;else if(read_busy1)last_owner<=1;
  if(previous_busy&&!any_read_busy)turn<=~last_owner;
 end
end
wfifo_32_32_512 write_buf
	(
	.clkr                      	(mem_clk                  ),          // Read side clock
	.clkw                      	(write_clk                ),          // Write side clock
	.rst                       	(write_fifo_aclr|rst      ),          // Asynchronous clear
	.we                      	(write_en                 ),          // Write Request
	.re                      	(App_wr_en        		  ),          // Read Request
	.di                       	(write_data               ),          // Input Data
	.empty_flag                 (                         ),          // Read side Empty flag
	.full_flag                  (write_full               ),          // Write side Full flag
	.wrusedw                	(              	  		  ),          // Read Used Words
	.rdusedw                	(rdusedw                  ),          // Write Used Words
	.dout                       (App_wr_din		          )
);
frame_fifo_write
#
(
	.MEM_DATA_BITS              (MEM_DATA_BITS            ),
	.ADDR_BITS                  (ADDR_BITS                ),
	.BURST_BITS                 (BURST_BITS               ),
	.BURST_SIZE                 (BURST_SIZE               ),
	.WRITE_V_FLIP               (WRITE_V_FLIP             ),
	.FRAME_WIDTH                (FRAME_WIDTH              ),
	.FRAME_HEIGHT               (FRAME_HEIGHT             )
) 
frame_fifo_write_m0              
(  
	.write_top_down(write_top_down),
	.rst                        (rst                      ),
	.mem_clk                    (mem_clk                  ),
    .Sdr_init_done				(Sdr_init_done),
	.Sdr_init_ref_vld			(Sdr_init_ref_vld),
    .Sdr_busy					(Sdr_busy),
	.App_rd_busy				(App_rd_busy),
    .O_wr_busy					(O_wr_busy),
	
	.App_wr_en					(App_wr_en),
    .App_wr_addr				(App_wr_addr),
	.write_req                  (write_req                ),
	.write_req_ack              (write_req_ack            ),
	.write_finish               (write_finish             ),
	.write_addr_0               (write_addr_0             ),
	.write_addr_1               (write_addr_1             ),
	.write_addr_2               (write_addr_2             ),
	.write_addr_3               (write_addr_3             ),
	.write_addr_index           (write_addr_index         ),    
	.write_len                  (write_len                ),
	.fifo_aclr                  (write_fifo_aclr          ),
	.rdusedw                 	({1'b0,rdusedw}           )
);

async_pixel_fifo #(.WIDTH(MEM_DATA_BITS),.AW(9)) read_buf0(
 .rst(clr0|rst),.wclk(mem_clk),.we(Sdr_rd_en && last_owner==1'b0),.din(Sdr_rd_dout),
 .rclk(read_clk),.re(read_en),.dout(data0),.full(full0),.empty(empty0),
 .wcount(rdusedw0),.rcount(unused0));
frame_fifo_read #(.MEM_DATA_BITS(MEM_DATA_BITS),.ADDR_BITS(ADDR_BITS),
 .BURST_BITS(BURST_BITS),.BURST_SIZE(BURST_SIZE)) frame_fifo_read_0(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(Sdr_init_done),
 .Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),.Sdr_rd_en(Sdr_rd_en),
 .App_wr_busy(O_wr_busy || !choose0),.O_rd_busy(read_busy0),.want_read(want0),
 .App_rd_en(en0),.App_rd_addr(addr0),.read_req(read_req),.read_req_ack(ack0),
 .read_finish(finish0),.read_addr_0(read_addr_0),.read_addr_1(read_addr_1),
 .read_addr_2(read_addr_2),.read_addr_3(read_addr_3),.read_addr_index(2'd0),
 .read_len(read_len),.fifo_aclr(clr0),.wrusedw(rdusedw0));

async_pixel_fifo #(.WIDTH(MEM_DATA_BITS),.AW(9)) read_buf1(
 .rst(clr1|rst),.wclk(mem_clk),.we(Sdr_rd_en && last_owner==1'b1),.din(Sdr_rd_dout),
 .rclk(read_clk),.re(read_en),.dout(data1),.full(full1),.empty(empty1),
 .wcount(rdusedw1),.rcount(unused1));
frame_fifo_read #(.MEM_DATA_BITS(MEM_DATA_BITS),.ADDR_BITS(ADDR_BITS),
 .BURST_BITS(BURST_BITS),.BURST_SIZE(BURST_SIZE)) frame_fifo_read_1(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(Sdr_init_done),
 .Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),.Sdr_rd_en(Sdr_rd_en),
 .App_wr_busy(O_wr_busy || !choose1),.O_rd_busy(read_busy1),.want_read(want1),
 .App_rd_en(en1),.App_rd_addr(addr1),.read_req(read_req),.read_req_ack(ack1),
 .read_finish(finish1),.read_addr_0(read_addr_0),.read_addr_1(read_addr_1),
 .read_addr_2(read_addr_2),.read_addr_3(read_addr_3),.read_addr_index(2'd1),
 .read_len(read_len),.fifo_aclr(clr1),.wrusedw(rdusedw1));

always @(posedge read_clk or posedge read_rst)begin
 if(read_rst)read_underflow<=0;
 else if(read_req||!read_check)read_underflow<=0;
 else if(read_en&&(empty0||empty1))read_underflow<=1;
end
always @(posedge mem_clk or posedge rst)begin
 if(rst)read_overflow<=0;
 else if(Sdr_rd_en && ((last_owner==0&&full0&&!clr0)||(last_owner==1&&full1&&!clr1)))read_overflow<=1;
end
endmodule
