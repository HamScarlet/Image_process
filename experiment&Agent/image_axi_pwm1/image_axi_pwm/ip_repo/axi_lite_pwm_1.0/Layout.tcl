# The Command Lines that defined the layout and widget properties.

set Tab_Tab_0 [add_tab -name {Tab_0} -col_count {1}]

set Spin_Box_C_S_AXI_ADDR_WIDTH [add_param -parent {Tab_0} -name {C_S_AXI_ADDR_WIDTH} -widget {Spin Box}]
set_widget_prop -widget_id $Spin_Box_C_S_AXI_ADDR_WIDTH -prop {Display Name} -value {C_S_AXI_ADDR_WIDTH}
set_widget_prop -widget_id $Spin_Box_C_S_AXI_ADDR_WIDTH -prop {Cell Number} -value {4}
set_widget_prop -widget_id $Spin_Box_C_S_AXI_ADDR_WIDTH -prop {Label Align} -value {right}

set Line_Edit_RESET_MOTOR_ARR_Display [add_param -parent {Tab_0} -name {RESET_MOTOR_ARR_Display} -widget {Line Edit}]
set_widget_prop -widget_id $Line_Edit_RESET_MOTOR_ARR_Display -prop {Display Name} -value {RESET_MOTOR_ARR}
set_widget_prop -widget_id $Line_Edit_RESET_MOTOR_ARR_Display -prop {Cell Number} -value {4}
set_widget_prop -widget_id $Line_Edit_RESET_MOTOR_ARR_Display -prop {Label Align} -value {right}

set Line_Edit_RESET_SERVO_ARR_Display [add_param -parent {Tab_0} -name {RESET_SERVO_ARR_Display} -widget {Line Edit}]
set_widget_prop -widget_id $Line_Edit_RESET_SERVO_ARR_Display -prop {Display Name} -value {RESET_SERVO_ARR}
set_widget_prop -widget_id $Line_Edit_RESET_SERVO_ARR_Display -prop {Cell Number} -value {4}
set_widget_prop -widget_id $Line_Edit_RESET_SERVO_ARR_Display -prop {Label Align} -value {right}

set Line_Edit_RESET_MOTOR_ARR [add_param -parent {} -name {RESET_MOTOR_ARR} -widget {Line Edit}]

set Line_Edit_RESET_SERVO_ARR [add_param -parent {} -name {RESET_SERVO_ARR} -widget {Line Edit}]