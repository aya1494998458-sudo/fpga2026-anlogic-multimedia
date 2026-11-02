`timescale 1ns/1ps
// Both FAT32 readers share one sector service while WAV PCM is backpressured.
module tb_av_storage;
reg clk=0;always #5 clk=~clk;
reg rst=1,sdready=0,io=0,ao=0;
wire im,am,ifs,afs,ieof,aeof,iv,av,ir,ar,ise,ase,isv,asv;
wire [2:0] ic,ac;wire [3:0] ierr,aerr,werr;wire [31:0] iz,az,ia,aa,addr;
wire [7:0] ib,ab,isd,asd;wire sr;reg [7:0] data;reg sv=0,se=0;
wire frame_valid,format_ok,wav_done;wire [47:0] frame;
reg [31:0] cycles=0;wire image_ready=cycles%7<5;wire frame_ready=cycles%17<9;
wire wav_ready;
fat32_reader imagefs(clk,rst,sdready,io,2'd0,im,ic,ierr,iz,ifs,ib,iv,image_ready,ieof,ir,ia,isd,isv,ise);
fat32_reader #(.EXT0("W"),.EXT1("A"),.EXT2("V"),.MAX_FILES(1),.MIN_FILE_SIZE(44)) audiofs(
 clk,rst,sdready,ao,2'd0,am,ac,aerr,az,afs,ab,av,wav_ready,aeof,ar,aa,asd,asv,ase);
wav_pcm_decoder decoder(clk,rst,afs,az,ab,av,wav_ready,aeof,frame,frame_valid,frame_ready,format_ok,wav_done,werr);
sd_sector_arbiter arb(clk,rst,ir,ia,ar,aa,sr,addr,data,sv,se,isd,isv,ise,asd,asv,ase,1'b1);
reg [7:0] disk[0:8191];reg [47:0] expected[0:76];integer ni=0,nw=0,j=0,lba=0;
reg image_done=0;reg [1:0] state=0;
always @(negedge clk)begin
 cycles=cycles+1;sv=0;se=0;
 if(!rst)case(state)
 0:if(sr)begin lba=addr;j=0;state=1;end
 1:if(cycles%3!=0)begin data=disk[lba*512+j];sv=1;if(j==511)state=2;else j=j+1;end
 2:begin se=1;state=3;end
 3:if(!sr)state=0;
 endcase
end
always @(posedge clk)begin
 if(iv&&image_ready)begin if(ib!==((ni*17+3)&255))$fatal(1,"BMP bytes corrupted by audio arbitration");ni=ni+1;end
 if(ieof)image_done=1;
 if(frame_valid&&frame_ready)begin if(frame!==expected[nw])$fatal(1,"WAV frames corrupted by image arbitration");nw=nw+1;end
 if(wav_done)begin
  if(ierr||aerr||werr||nw!=77)$fatal(1,"WAV/shared storage incomplete");
 end
end
initial begin
 $readmemh("assets/wav_tests/av_disk.hex",disk);$readmemh("assets/wav_tests/stereo24_frames.hex",expected);
 #35;rst=0;sdready=1;wait(im&&am);if(ic!=1||ac!=1)$fatal(1,"directory extension filtering");
 @(negedge clk);io=1;ao=1;@(negedge clk);io=0;ao=0;
 wait(image_done&&nw==77);if(ni!=800)$fatal(1,"BMP stream length");
 $display("PASS simultaneous BMP/WAV FAT32 readers, fragmented files and shared SD sector arbitration");$finish;
end
initial begin #5000000;$fatal(1,"AV storage timeout image%d audio%d",ni,nw);end
endmodule
