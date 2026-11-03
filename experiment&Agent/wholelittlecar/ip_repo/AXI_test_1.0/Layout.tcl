# The Command Lines that defined the layout and widget properties.

set Tab_Tab_0 [add_tab -name {Tab_0} -col_count {1}]

set Line_Edit_RUN_TARGET_Display [add_param -parent {Tab_0} -name {RUN_TARGET_Display} -widget {Line Edit}]
set_widget_prop -widget_id $Line_Edit_RUN_TARGET_Display -prop {Display Name} -value {RUN_TARGET}
set_widget_prop -widget_id $Line_Edit_RUN_TARGET_Display -prop {Cell Number} -value {4}
set_widget_prop -widget_id $Line_Edit_RUN_TARGET_Display -prop {Label Align} -value {right}

set Line_Edit_RUN_TARGET [add_param -parent {} -name {RUN_TARGET} -widget {Line Edit}]