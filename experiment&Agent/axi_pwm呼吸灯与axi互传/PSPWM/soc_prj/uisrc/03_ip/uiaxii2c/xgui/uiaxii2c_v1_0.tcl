# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "I2C_FREQ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SYSCLK_FREQ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WMEN_LEN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RMEN_LEN" -parent ${Page_0}


}

proc update_PARAM_VALUE.I2C_FREQ { PARAM_VALUE.I2C_FREQ } {
	# Procedure called to update I2C_FREQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.I2C_FREQ { PARAM_VALUE.I2C_FREQ } {
	# Procedure called to validate I2C_FREQ
	return true
}

proc update_PARAM_VALUE.RMEN_LEN { PARAM_VALUE.RMEN_LEN } {
	# Procedure called to update RMEN_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RMEN_LEN { PARAM_VALUE.RMEN_LEN } {
	# Procedure called to validate RMEN_LEN
	return true
}

proc update_PARAM_VALUE.SYSCLK_FREQ { PARAM_VALUE.SYSCLK_FREQ } {
	# Procedure called to update SYSCLK_FREQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SYSCLK_FREQ { PARAM_VALUE.SYSCLK_FREQ } {
	# Procedure called to validate SYSCLK_FREQ
	return true
}

proc update_PARAM_VALUE.WMEN_LEN { PARAM_VALUE.WMEN_LEN } {
	# Procedure called to update WMEN_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WMEN_LEN { PARAM_VALUE.WMEN_LEN } {
	# Procedure called to validate WMEN_LEN
	return true
}


proc update_MODELPARAM_VALUE.SYSCLK_FREQ { MODELPARAM_VALUE.SYSCLK_FREQ PARAM_VALUE.SYSCLK_FREQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SYSCLK_FREQ}] ${MODELPARAM_VALUE.SYSCLK_FREQ}
}

proc update_MODELPARAM_VALUE.I2C_FREQ { MODELPARAM_VALUE.I2C_FREQ PARAM_VALUE.I2C_FREQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.I2C_FREQ}] ${MODELPARAM_VALUE.I2C_FREQ}
}

proc update_MODELPARAM_VALUE.WMEN_LEN { MODELPARAM_VALUE.WMEN_LEN PARAM_VALUE.WMEN_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WMEN_LEN}] ${MODELPARAM_VALUE.WMEN_LEN}
}

proc update_MODELPARAM_VALUE.RMEN_LEN { MODELPARAM_VALUE.RMEN_LEN PARAM_VALUE.RMEN_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RMEN_LEN}] ${MODELPARAM_VALUE.RMEN_LEN}
}

