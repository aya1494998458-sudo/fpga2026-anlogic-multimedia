# Audited first synchronization stages only. Gray datapath bound 10ns.
# Flat SDC commands, compatible with TD read_sdc parser.
set_max_delay -to [get_regs {memory/read_buf0/rg1[*]}] 10.0 -datapath_only
set_max_delay -to [get_regs {memory/read_buf1/rg1[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {memory/read_buf0/rg1[*]}]
set_false_path -hold -to [get_regs {memory/read_buf1/rg1[*]}]
set_max_delay -to [get_regs {memory/read_buf0/wg1[*]}] 10.0 -datapath_only
set_max_delay -to [get_regs {memory/read_buf1/wg1[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {memory/read_buf0/wg1[*]}]
set_false_path -hold -to [get_regs {memory/read_buf1/wg1[*]}]
set_max_delay -to [get_regs {control/next_sync[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {control/next_sync[0]}]
set_max_delay -to [get_regs {control/complete_sync[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {control/complete_sync[0]}]
set_max_delay -to [get_regs {transition/sync_commit[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {transition/sync_commit[0]}]
set_max_delay -to [get_regs {transition/sync_bank[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {transition/sync_bank[0]}]
set_max_delay -to [get_regs {busy_sync[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {busy_sync[0]}]
set_max_delay -to [get_regs {ack_sync[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {ack_sync[0]}]
set_max_delay -to [get_regs {meta_w0[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {meta_w0[*]}]
set_max_delay -to [get_regs {meta_h0[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {meta_h0[*]}]
set_max_delay -to [get_regs {meta_f0[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {meta_f0[*]}]
set_max_delay -to [get_regs {meta_e0[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {meta_e0[*]}]
set_max_delay -to [get_regs {memory/frame_fifo_read_0/read_req_d0}] 10.0 -datapath_only
set_max_delay -to [get_regs {memory/frame_fifo_read_1/read_req_d0}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {memory/frame_fifo_read_0/read_req_d0}]
set_false_path -hold -to [get_regs {memory/frame_fifo_read_1/read_req_d0}]
set_max_delay -to [get_regs {status0[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {status0[*]}]
# Asynchronous reset is synchronized separately inside the pixel FIFO.
# Only entry to the reset synchronizer from the memory domain is asynchronous;
# recovery/removal on the downstream pixel-domain registers remains analyzed.
set_false_path -from [get_clocks {ext_mem_clk}] -to [get_regs {memory/read_buf0/rreset/s[*]}]
set_false_path -from [get_clocks {ext_mem_clk}] -to [get_regs {memory/read_buf1/rreset/s[*]}]

set_max_delay -to [get_regs {wav_buffer/rg1[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {wav_buffer/rg1[*]}]

set_max_delay -to [get_regs {wav_buffer/wg1[*]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {wav_buffer/wg1[*]}]

set_max_delay -to [get_regs {wav_output/format_sync[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {wav_output/format_sync[0]}]

set_max_delay -to [get_regs {wav_output/error_sync[0]}] 10.0 -datapath_only
set_false_path -hold -to [get_regs {wav_output/error_sync[0]}]
set_false_path -from [get_clocks {ext_mem_clk}] -to [get_regs {wav_buffer/rreset/s[*]}]
# Asynchronous external keys/switches terminate only at GPIO first stage.
set_false_path -from [get_ports {key_n[*] sw_level[*]}] -to [get_regs {ui/sync0[*]}]
