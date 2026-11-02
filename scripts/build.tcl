set root [file normalize [file join [file dirname [info script]] ..]]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out $root/reports/build_$stamp
file mkdir $out
puts "BUILD_OUTPUT $out"
cd $root/project/src/td_project
if {[catch {
 import_device eagle_s20.db -package EG4S20BG256
 open_project -single_run HDMI1.4b_Transmitter_v1.0.al
 cd $out
 elaborate -top top
 read_adc $root/project/src/user_source/constraints_source/pin.adc
 read_sdc $root/project/src/user_source/constraints_source/timing.sdc
 read_sdc $root/project/src/user_source/constraints_source/cdc.sdc
 read_sdc -ip rfifo_32_32_512 $root/project/src/user_source/hdl_source/IP/afifo_32_16_256.tcl
 read_sdc -ip wfifo_32_32_512 $root/project/src/user_source/hdl_source/IP/afifo_16_32_256.tcl
 insert_debugger
 optimize_rtl
 export_db integrated_rtl.db
 report_area -file rtl.area
 puts "STAGE RTL COMPLETED"
 set_param gate pack_seq_in_io off
 optimize_gate -packarea gate.area
 legalize_phy_inst
 export_db integrated_gate.db
 report_timing_summary -file gate.timing
 puts "STAGE SYNTHESIS COMPLETED"
 place
 export_db integrated_place.db
 report_timing_summary -file place.timing
 puts "STAGE PLACE COMPLETED"
 route
 update_timing -mode final
 report_timing_status -file final.ts
 report_timing_summary -file final.timing
 report_timing_exception -file exceptions.timing
 report_area -io_info -file final.area
 export_db integrated_route.db
 flow_status -file final.status
 puts "STAGE ROUTE COMPLETED"
 bitgen -bit Contest1_All_Extensions.bit
 puts "STAGE BITGEN COMPLETED"
} message options]} {
 puts stderr "BUILD FAILED: $message"
 if {[dict exists $options -errorinfo]} {puts stderr [dict get $options -errorinfo]}
 exit 1
}
exit

