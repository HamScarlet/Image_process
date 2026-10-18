source "E:/FPGA/Anlu/cw/atpl/templa.tcl"
set fd [open "E:/FPGA/Anlu/cw/atpl/cwc.atpl" r]
set tmpl [read $fd]
close $fd
set parser [::tmpl_parser::tmpl_parser $tmpl]

set ComponentName        auto_created_cwc1
set bus_num              14
set cwc_ctrl_len         409
set cwc_bus_ctrl_len     389
set bus_din_num          117
set ram_len              117
set input_pipe_num       0
set output_pipe_num      0
set depth                1024
set capture_ctrl_exist   0
set bus_width            { 16,9,9,9,4,16,16,32,1,1,1,1,1,1 };
set bus_din_pos          { 0,16,25,34,43,47,63,79,111,112,113,114,115,116 };
set bus_ctrl_pos         { 0,52,83,114,145,161,213,265,365,369,373,377,381,385 };
set fp [open "cw/auto_created_cwc1/auto_created_cwc1_watcherInst.sv" w+]
puts $fp [eval $parser]
close $fp
