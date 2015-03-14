;Default settings
SettingFlowExecutionPolicy=parallel

ui_SettingsOwFLow()
{
	global
	
	ui_DisableMainGUI()
	gui,5:default
	gui,+owner
	gui,add,text,x10 w300,% lang("Flow_ececution_policy")
	if SettingFlowExecutionPolicy=parallel
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsParallel checked%tempchecked%,% lang("Parallel_execution_of_multiple_instances")
		if SettingFlowExecutionPolicy=skip
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsSkip checked%tempchecked% ,% lang("Skip_execution_when_an_instance_is_already_executing")
		if SettingFlowExecutionPolicy=wait
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsWait  checked%tempchecked%,% lang("Wait_until_the_currently_executing_instance_has_finished")
		if SettingFlowExecutionPolicy=stop
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsStop  checked%tempchecked%,% lang("Stop_the_currently_executing_instance_and_execute_afterwards")
	 
	
	
	gui,add,button,w90 x10 h30 Y+20 gGuiFlowSettingsOK,% lang("OK")
	gui,add,button,w90 X+10 h30 yp gGuiFlowSettingsCancel,% lang("Cancel")
	gui,show
	return
	
	
	GuiFlowSettingsOK:
	
	gui,submit
	if GuiFlowSettingsParallel=1
		SettingFlowExecutionPolicy=parallel
	else if GuiFlowSettingsSkip=1
		SettingFlowExecutionPolicy=skip
	else if GuiFlowSettingsWait=1
		SettingFlowExecutionPolicy=wait		
	else if GuiFlowSettingsStop=1
		SettingFlowExecutionPolicy=stop
	gui,destroy
	ui_EnableMainGUI()
	return
	
	GuiFlowSettingsCancel:
	
	gui,destroy
	ui_EnableMainGUI()
	return
	
	
	
}


