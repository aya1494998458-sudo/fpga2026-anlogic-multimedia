// Integrated single-image system. See README for bounded BMP/FAT32 support.
module top(input clk,input [3:0] key_n,input [3:0] sw_level,
 output [5:0] seg_sel,output [7:0] seg_data,
 output HDMI_CLK_P,HDMI_D2_P,HDMI_D1_P,HDMI_D0_P,
 output HDMI_DDC_SCL,inout HDMI_DDC_SDA,
 output sd_ncs,sd_dclk,sd_mosi,input sd_miso);
wire rst_n=key_n[0];
wire sd_card_clk,ext_mem_clk,ext_mem_clk_sft,video_clk,hdmi_5x_clk;
wire audio_pll_lock,audio_mclk;
wire rst_all=~rst_n|~audio_pll_lock;
wire mrst,vrst;
reset_sync rm(ext_mem_clk,rst_all,mrst);
reset_sync rv(video_clk,rst_all,vrst);
wire audio_i2s_bclk,audio_i2s_lrck,audio_i2s_dout,audio_valid;
wire [23:0] audio_left_data,audio_right_data;
wire tone_audio_valid;wire [23:0] tone_left,tone_right;
wire wav_selected,wav_underrun,wav_sample_valid,audio_mute;
wire [23:0] wav_left,wav_right;
wire acr_valid;wire [19:0] acr_cts,acr_n;
wire axis_s_user,axis_s_valid,axis_s_last,axis_s_ready;
wire [23:0] axis_s_data;
wire edid_trig,edid_valid;wire [7:0] edid_data;
wire [9:0] tmds_ch0_data,tmds_ch1_data,tmds_ch2_data,tmds_clk_data;
// 750 MHz/61 PLL output; CE ratio 15616/15625 yields 12.288 MHz
// effective serializer tick rate, and exactly 48 kHz average PCM rate.
reg [13:0] audio_frac;
wire [14:0] audio_sum={1'b0,audio_frac}+15'd15616;
wire audio_ce=audio_sum>=15625;
always @(posedge audio_mclk or posedge rst_all)
 if(rst_all)audio_frac<=0;else audio_frac<=audio_ce?audio_sum-15625:audio_sum;
sys_pll sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .reset      (1'b0)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .reset      (1'b0)
);

// 复用你 I2S->HDMI 工程里的 PLL，只取 12.288MHz 音频主时钟
PLL_HDMI_AUDIO u_audio_pll(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (audio_pll_lock),
    .clk0_out   (),
    .clk1_out   (),
    .clk2_out   (audio_mclk)
);


wire Sdr_init_done,Sdr_init_ref_vld,Sdr_busy;
wire App_rd_en,App_wr_en,Sdr_rd_en;wire [20:0] App_rd_addr,App_wr_addr;
wire [31:0] App_wr_din,Sdr_rd_dout;wire [3:0] App_wr_dm;
wire sdready,sec_req,sec_valid,sec_end;wire [31:0] sec_addr;wire [7:0] sec_data;
wire mounted,file_open,file_start,eof,byte_valid,byte_ready;
wire [7:0] file_data;wire [31:0] file_size;wire [2:0] file_count;
wire [1:0] file_index;wire [3:0] fat_error,load_error;
wire wr_req,wr_ack,wr_valid,wr_ready,wr_finish,top_down,loader_done;
wire [23:0] loaded_pixel;wire [15:0] source_width,source_height;
wire target_bank,commit_toggle,completed_toggle,next_toggle,media_busy;
wire auto_play,osd_enable,transition_busy,display_valid,old_bank,new_bank;
wire [8:0] alpha,contrast;wire signed [8:0] brightness;
wire [2:0] menu;wire [1:0] visual_mode,transition_mode;wire [7:0] fade_frames;
wire frame_tick;
reg [1:0] busy_sync;
always @(posedge video_clk or posedge vrst)if(vrst)busy_sync<=3;else busy_sync<={busy_sync[0],media_busy};
media_ui ui(video_clk,vrst,key_n,sw_level,frame_tick,busy_sync[1],next_toggle,
 auto_play,osd_enable,brightness,contrast,menu,visual_mode,transition_mode,fade_frames,audio_mute);
media_control control(ext_mem_clk,mrst,mounted,file_count,file_start,loader_done,
 load_error,wr_finish,file_open,file_index,target_bank,commit_toggle,
 completed_toggle,next_toggle,media_busy);
frame_transition transition(video_clk,vrst,frame_tick,commit_toggle,target_bank,
 fade_frames,transition_mode,completed_toggle,display_valid,old_bank,new_bank,alpha,transition_busy);

// Independent FAT readers arbitrate complete SD sector transactions.
wire image_req,image_valid,image_end;wire [31:0] image_addr;wire [7:0] image_data;
wire wav_req,wav_sec_valid,wav_sec_end;wire [31:0] wav_addr;wire [7:0] wav_sec_data;
wire wav_mounted,wav_open,wav_start,wav_eof,wav_byte_valid,wav_byte_ready;
wire [2:0] wav_count;wire [3:0] wav_fs_error,wav_decode_error;
wire [31:0] wav_size;wire [7:0] wav_byte;
wire wav_format_ok,wav_done,wav_available,wav_failed;
wire [47:0] wav_frame,wav_fifo_data;wire wav_frame_valid,wav_fifo_full,wav_fifo_empty,wav_fifo_read;
wire [12:0] wav_wcount,wav_rcount;
reg wav_urgent;
always @(posedge ext_mem_clk or posedge mrst)
 if(mrst)wav_urgent<=1;else wav_urgent<=wav_wcount<1024;
sd_sector_arbiter card_arbiter(ext_mem_clk,mrst,image_req,image_addr,wav_req,wav_addr,
 sec_req,sec_addr,sec_data,sec_valid,sec_end,image_data,image_valid,image_end,
 wav_sec_data,wav_sec_valid,wav_sec_end,wav_urgent);
fat32_reader #(.EXT0("W"),.EXT1("A"),.EXT2("V"),.MAX_FILES(1),.MIN_FILE_SIZE(44)) wav_fs(
 ext_mem_clk,mrst,sdready,wav_open,2'd0,wav_mounted,wav_count,wav_fs_error,
 wav_size,wav_start,wav_byte,wav_byte_valid,wav_byte_ready,wav_eof,
 wav_req,wav_addr,wav_sec_data,wav_sec_valid,wav_sec_end);
wav_pcm_decoder wav_decoder(ext_mem_clk,mrst,wav_start,wav_size,wav_byte,
 wav_byte_valid,wav_byte_ready,wav_eof,wav_frame,wav_frame_valid,!wav_fifo_full,
 wav_format_ok,wav_done,wav_decode_error);
wav_file_control wav_control(ext_mem_clk,mrst,wav_mounted,wav_count,wav_done,
 wav_format_ok,wav_decode_error,wav_fs_error,wav_open,wav_available,wav_failed);
async_pixel_fifo #(.WIDTH(48),.AW(12)) wav_buffer(mrst,ext_mem_clk,
 wav_frame_valid&&!wav_fifo_full,wav_frame,video_clk,wav_fifo_read,wav_fifo_data,
 wav_fifo_full,wav_fifo_empty,wav_wcount,wav_rcount);
wav_audio_output wav_output(video_clk,vrst,wav_available,wav_failed,
 wav_fifo_data,wav_fifo_empty,wav_rcount,wav_fifo_read,wav_selected,wav_underrun,
 wav_sample_valid,wav_left,wav_right);
assign audio_valid=wav_selected?wav_sample_valid:tone_audio_valid;
assign audio_left_data=audio_mute?24'd0:(wav_selected?wav_left:tone_left);
assign audio_right_data=audio_mute?24'd0:(wav_selected?wav_right:tone_right);

sd_card_top #(.SPI_LOW_SPEED_DIV(248),.SPI_HIGH_SPEED_DIV(1)) sd(
 .clk(ext_mem_clk),.rst(mrst),.SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),.SD_MOSI(sd_mosi),.SD_MISO(sd_miso),
 .sd_init_done(sdready),.sd_sec_read(sec_req),.sd_sec_read_addr(sec_addr),
 .sd_sec_read_data(sec_data),.sd_sec_read_data_valid(sec_valid),.sd_sec_read_end(sec_end),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
 .sd_sec_write_data_req(),.sd_sec_write_end());
fat32_reader fs(ext_mem_clk,mrst,sdready,file_open,file_index,mounted,file_count,
 fat_error,file_size,file_start,file_data,byte_valid,byte_ready,eof,
 image_req,image_addr,image_data,image_valid,image_end);
bmp_bilinear_loader scaler(ext_mem_clk,mrst,file_start,file_size,file_data,
 byte_valid,byte_ready,eof,wr_req,wr_ack,loaded_pixel,wr_valid,wr_ready,
 top_down,loader_done,load_error,source_width,source_height);
wire hs0,vs0,de0,hs,vs,de,read_req,read_ack,read_en;
wire [63:0] pair,pair_delayed;wire underflow,overflow;
reg [1:0] ack_sync;
always @(posedge video_clk or posedge vrst)if(vrst)ack_sync<=0;else ack_sync<={ack_sync[0],read_ack};
video_timing_data timing(video_clk,vrst,read_req,ack_sync[1],hs0,vs0,de0);
video_delay #(.DATA_WIDTH(64)) delay_pixels(video_clk,vrst,read_en,pair,hs0,vs0,de0,hs,vs,de,pair_delayed);
frame_read_write #(.READ_DATA_BITS(64),.WRITE_V_FLIP(1),.FRAME_WIDTH(640),.FRAME_HEIGHT(480)) memory(
 .write_top_down(top_down),.read_check(display_valid),.read_rst(vrst),.write_ready(wr_ready),.read_underflow(underflow),.read_overflow(overflow),
 .mem_clk(ext_mem_clk),.rst(mrst),.Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
 .App_rd_en(App_rd_en),.App_rd_addr(App_rd_addr),.Sdr_rd_en(Sdr_rd_en),.Sdr_rd_dout(Sdr_rd_dout),
 .read_clk(video_clk),.read_req(read_req),.read_req_ack(read_ack),.read_finish(),
 .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),
 .read_addr_index(2'd0),.read_len(21'd307200),.read_en(read_en),.read_data(pair),
 .App_wr_en(App_wr_en),.App_wr_addr(App_wr_addr),.App_wr_din(App_wr_din),.App_wr_dm(App_wr_dm),
 .write_clk(ext_mem_clk),.write_req(wr_req),.write_req_ack(wr_ack),.write_finish(wr_finish),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd307200),
 .write_addr_index({1'b0,target_bank}),.write_len(21'd307200),
 .write_en(wr_valid&&wr_ready),.write_data({loaded_pixel,8'd0}));
sdram U3(.Clk(ext_mem_clk),.Clk_sft(ext_mem_clk_sft),.Rst(mrst),
 .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
 .App_wr_en(App_wr_en),.App_wr_addr(App_wr_addr),.App_wr_dm(App_wr_dm),.App_wr_din(App_wr_din),
 .App_rd_en(App_rd_en),.App_rd_addr(App_rd_addr),.Sdr_rd_en(Sdr_rd_en),.Sdr_rd_dout(Sdr_rd_dout));
wire [3:0] status_error=fat_error!=0?fat_error:load_error!=0?load_error:overflow?4'h4:underflow?4'h5:wav_failed?4'h6:wav_underrun?4'h7:4'h0;
wire [3:0] state_code=status_error!=0?status_error:!sdready?0:!mounted?2:!Sdr_init_done?3:media_busy?4:1;
wire [6:0] status_segments;
reg [3:0] status0,status1;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin status0<=0;status1<=0;end else begin status0<=state_code;status1<=status0;end
end
seg_decoder dec(status1,status_segments);
seg_scan seg(clk,rst_n,seg_sel,seg_data,8'hff,8'hff,8'hff,8'hff,8'hff,{1'b1,status_segments});
// Bundled metadata is stable well before commit_toggle; synchronize before OSD.
reg [15:0] meta_w0,meta_w1,meta_h0,meta_h1;
reg [1:0] meta_f0,meta_f1;reg [3:0] meta_e0,meta_e1;
always @(posedge video_clk or posedge vrst)begin
 if(vrst)begin meta_w0<=0;meta_w1<=0;meta_h0<=0;meta_h1<=0;meta_f0<=0;meta_f1<=0;meta_e0<=0;meta_e1<=0;end
 else begin meta_w0<=source_width;meta_w1<=meta_w0;meta_h0<=source_height;meta_h1<=meta_h0;
 meta_f0<=file_index;meta_f1<=meta_f0;meta_e0<=status_error;meta_e1<=meta_e0;end
end
wire [23:0] enhanced_rgb;wire enhanced_hs,enhanced_vs,enhanced_de;
video_effects effects(video_clk,vrst,hs,vs,de,pair_delayed,display_valid,old_bank,new_bank,
 alpha,transition_mode,brightness,contrast,osd_enable,auto_play,menu,meta_f1,
 meta_w1,meta_h1,visual_mode,audio_valid,audio_left_data,meta_e1,
 enhanced_rgb,enhanced_hs,enhanced_vs,enhanced_de,frame_tick);
video_rgb_to_axis_640x480 axis_video(video_clk,vrst,enhanced_vs,enhanced_de,
 enhanced_rgb,axis_s_user,axis_s_valid,axis_s_last,axis_s_data);
// ===================== 音频：内部 I2S 测试音 =====================
hdmi_audio_tone_i2s_64fs #(
    .PHASE_INC (32'd39370534),
    .AMP       (24'sd2000000)
) u_hdmi_audio_tone_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_ce(audio_ce),
    .I_rst       (rst_all),
    .O_i2s_BCLK  (audio_i2s_bclk),
    .O_i2s_LRCK  (audio_i2s_lrck),
    .O_i2s_DOUT  (audio_i2s_dout)
);

I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_all),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (tone_audio_valid),
    .O_audio_left_data  (tone_left),
    .O_audio_right_data (tone_right)
);

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_all),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (rst_all),
    .O_pulse (edid_trig)
);

// ===================== 带音频的 HDMI 1.4b 发射 =====================
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_all),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_all),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule
