# The Command Lines that defined the parameter attributes.

set_param -param_id {C_S_AXI_ADDR_WIDTH} -data_type {Integer} -min {-2147483648} -max {2147483647}
set_param -param_id {RESET_MOTOR_ARR_Display} -data_type {String} -validator {[-0-9]*('[BbOoDdHh])?(-)?[0-9a-fA-F_]+}
set_param -param_id {RESET_SERVO_ARR_Display} -data_type {String} -validator {[-0-9]*('[BbOoDdHh])?(-)?[0-9a-fA-F_]+}
set_param -param_id {RESET_MOTOR_ARR} -data_type {Integer} -value {updateRelValue $RESET_MOTOR_ARR_Display}
set_param -param_id {RESET_SERVO_ARR} -data_type {Integer} -value {updateRelValue $RESET_SERVO_ARR_Display}
# The Tcl Procs that used in parameter dependency.

proc updateRelValue { value } {
 set tmp $value
 return $tmp
}