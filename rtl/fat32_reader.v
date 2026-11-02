// Read-only FAT32 root-directory BMP streamer. Fragmented files and directories
// follow FAT chains. Supports an MBR first partition or a superfloppy BPB.
module fat32_reader #(parameter [7:0] EXT0="B",EXT1="M",EXT2="P",
 parameter MAX_FILES=4,parameter MIN_FILE_SIZE=54)
 (input clk,input rst,input sd_ready,
 input open_file,input [1:0] file_index,output reg mounted,
 output reg [2:0] file_count,output reg [3:0] error,
 output reg [31:0] file_size,output reg file_start,
 output [7:0] data,output valid,input ready,output reg eof,
 output reg sec_req,output reg [31:0] sec_addr,
 input [7:0] sec_data,input sec_valid,input sec_end);
 reg [7:0] bufmem[0:511];
 reg [7:0] boot[0:63],entry[0:31]; reg [4:0] entry_i;reg [1:0] fat_i;reg [31:0] fat_value,mbr_lba;reg [15:0] signature; reg [9:0] capture;
 reg [8:0] pos; reg [4:0] state,ret;
 reg [31:0] partition,fat_base,data_base,root_cluster,cluster,dir_cluster;
 reg [31:0] clusters[0:3],sizes[0:3];
 reg [7:0] spc,cluster_sector; reg [31:0] remaining;
 reg stream_last,stream_sector_end;
 reg [15:0] dir_entries; reg [1:0] fat_purpose;
 reg [31:0] timeout;
 reg [2:0] cluster_shift;reg [31:0] calc_cl,delta,calc_fats;
 reg [7:0] calc_sector;reg [4:0] calc_ret;
 function [2:0] logspc;input [7:0] v;begin case(v)
 1:logspc=0;2:logspc=1;4:logspc=2;8:logspc=3;16:logspc=4;32:logspc=5;64:logspc=6;default:logspc=7;endcase end endfunction
 localparam WAIT=0,BOOT=1,BPB=2,DIR=3,FAT=4,IDLE=5,STREAM=6,
            READ=7,RECEIVE=8,RESUME_FILE=9,FAIL=10,DIR_READ=11,FAT_READ=12;
 function [31:0] le32; input [8:0] a; begin
 le32={boot[a+3],boot[a+2],boot[a+1],boot[a]};end endfunction
 function [15:0] le16; input [8:0] a;begin le16={boot[a+1],boot[a]};end endfunction
 wire [31:0] next_cluster=fat_value & 32'h0fffffff;
 wire [8:0] cache_addr=(state==DIR_READ||state==18||state==19)?pos+entry_i:(state==FAT_READ||state==20||state==21)?{cluster[6:0],2'b00}+fat_i:pos;
 reg [7:0] cache_data;
 always @(posedge clk) cache_data<=bufmem[cache_addr];
 // STREAM is entered only with remaining>0; the last byte exits to IDLE.
 assign valid=state==STREAM;
 assign data=cache_data;
 task disk; input [31:0] lba; input [4:0] continuation;
 begin sec_addr<=lba; ret<=continuation;state<=READ;end endtask
 task cluster_disk;input [31:0] cl;input [7:0] sector;input [4:0] continuation;
 begin calc_cl<=cl;calc_sector<=sector;calc_ret<=continuation;state<=13;end endtask
 integer i;
 always @(posedge clk or posedge rst) begin
 if(rst) begin state<=WAIT; mounted<=0;file_count<=0;error<=0;file_start<=0;
 sec_req<=0;sec_addr<=0;capture<=0;pos<=0;partition<=0;spc<=0;
 eof<=0;file_size<=0;remaining<=0;timeout<=0;dir_entries<=0;
 for(i=0;i<4;i=i+1)begin clusters[i]<=0;sizes[i]<=0;end
 end else begin
 file_start<=0;eof<=0;
 if(state==RECEIVE) begin
  if(timeout==32'd125000000) begin error<=4'hf;sec_req<=0;state<=FAIL;end
  else timeout<=timeout+1;
 end
 case(state)
 WAIT: if(sd_ready)disk(0,BOOT);
 READ: begin capture<=0;sec_req<=1;timeout<=0;state<=RECEIVE;end
 RECEIVE:begin
  if(sec_valid)begin
   bufmem[capture[8:0]]<=sec_data;capture<=capture+1;
   if(capture<64)boot[capture[5:0]]<=sec_data;
   case(capture)
   454:mbr_lba[7:0]<=sec_data;455:mbr_lba[15:8]<=sec_data;
   456:mbr_lba[23:16]<=sec_data;457:mbr_lba[31:24]<=sec_data;
   510:signature[7:0]<=sec_data;511:signature[15:8]<=sec_data;
   endcase
  end
  if(sec_end)begin sec_req<=0;pos<=0;entry_i<=0;fat_i<=0;state<=ret==STREAM?22:ret;end
 end
 BOOT:begin
  if(le16(11)==512 && boot[13]!=0)begin partition<=0;state<=BPB;end
  else if(signature==16'haa55)begin
   partition<=mbr_lba;disk(mbr_lba,BPB);
  end else begin error<=1;state<=FAIL;end
 end
 BPB:begin
  if(le16(11)!=512 || boot[13]==0 || (boot[13] & (boot[13]-1))!=0 ||
     le16(17)!=0 || le32(36)==0 || le32(44)<2 ||
     (boot[16]!=1&&boot[16]!=2))begin error<=2;state<=FAIL;end
  else begin
   spc<=boot[13];fat_base<=partition+le16(14);
   calc_fats<=boot[16]==2?(le32(36)<<1):le32(36);cluster_shift<=logspc(boot[13]);
   root_cluster<=le32(44);cluster<=le32(44);dir_cluster<=le32(44);
   cluster_sector<=0;dir_entries<=0;
   state<=16;
  end
 end
 13:begin delta<=calc_cl-2;state<=14;end
 14:begin delta<=delta<<cluster_shift;state<=15;end
 15:disk(data_base+delta+calc_sector,calc_ret);
 16:begin data_base<=fat_base+calc_fats;state<=17;end
 17:cluster_disk(root_cluster,0,DIR_READ);
 DIR_READ:begin entry_i<=0;state<=18;end
 18:state<=19;
 19:begin
  entry[entry_i]<=cache_data;
  if(entry_i==31)begin entry_i<=0;state<=DIR;end else begin entry_i<=entry_i+1;state<=18;end
 end
 FAT_READ:begin fat_i<=0;state<=20;end
 20:state<=21;
 21:begin
  fat_value[fat_i*8+:8]<=cache_data;
  if(fat_i==3)begin fat_i<=0;state<=FAT;end else begin fat_i<=fat_i+1;state<=20;end
 end
 22:begin stream_last<=remaining==1;stream_sector_end<=pos==511;state<=STREAM;end
 DIR:begin
  // Bound corrupt/cyclic directory chains; root only, short names, first 4 BMPs.
  if(entry[0]==0 || file_count==MAX_FILES || dir_entries==4095)begin mounted<=1;state<=IDLE;end
  else begin
   dir_entries<=dir_entries+1;
   if(entry[0]!=8'he5 && (entry[11]&8'h18)==0 && entry[11]!=8'h0f &&
      (entry[8]&8'hdf)==EXT0 && (entry[9]&8'hdf)==EXT1 &&
      (entry[10]&8'hdf)==EXT2 && {entry[31],entry[30],entry[29],entry[28]}>=MIN_FILE_SIZE)begin
    clusters[file_count[1:0]]<={{entry[21],entry[20]},{entry[27],entry[26]}};
    sizes[file_count[1:0]]<={entry[31],entry[30],entry[29],entry[28]};file_count<=file_count+1;
   end
   if(pos==480)begin
    pos<=0;
    if(cluster_sector+1<spc)begin cluster_sector<=cluster_sector+1;
     cluster_disk(dir_cluster,cluster_sector+1,DIR_READ);end
    else begin cluster<=dir_cluster;fat_purpose<=0;disk(fat_base+(dir_cluster>>7),FAT_READ);end
   end else begin pos<=pos+32;entry_i<=0;state<=DIR_READ;end
  end
 end
 FAT:begin
  if(next_cluster>=32'h0ffffff8)begin
   if(fat_purpose==0)begin mounted<=1;state<=IDLE;end
   else begin error<=3;state<=FAIL;end
  end else if(next_cluster<2 || next_cluster==32'h0ffffff7)begin error<=3;state<=FAIL;end
  else begin cluster<=next_cluster;cluster_sector<=0;
   if(fat_purpose==0)begin dir_cluster<=next_cluster;cluster_disk(next_cluster,0,DIR_READ);end
   else cluster_disk(next_cluster,0,STREAM);
  end
 end
 IDLE:if(open_file && file_index<file_count)begin
  cluster<=clusters[file_index];cluster_sector<=0;remaining<=sizes[file_index];
  file_size<=sizes[file_index];file_start<=1;
  cluster_disk(clusters[file_index],0,STREAM);
 end
 STREAM:if(valid && ready)begin
  remaining<=remaining-1;
  if(stream_last)begin eof<=1;state<=IDLE;end
  else if(stream_sector_end)begin
   pos<=0;
   if(cluster_sector+1<spc)begin cluster_sector<=cluster_sector+1;
    cluster_disk(cluster,cluster_sector+1,STREAM);end
   else begin fat_purpose<=1;disk(fat_base+(cluster>>7),FAT_READ);end
  end else begin pos<=pos+1;state<=22;end
 end
 default:;
 endcase
 end
 end
endmodule
