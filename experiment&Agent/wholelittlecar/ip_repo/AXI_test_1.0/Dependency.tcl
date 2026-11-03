# The Command Lines that defined the parameter attributes.

set_param -param_id {RUN_TARGET_Display} -data_type {String} -validator {[-0-9]*('[BbOoDdHh])?(-)?[0-9a-fA-F_]+}
set_param -param_id {RUN_TARGET} -data_type {Integer} -value {updateRelValue $RUN_TARGET_Display}
# The Tcl Procs that used in parameter dependency.

proc updateRelValue { value } {
 set tmp $value
 return $tmp
}