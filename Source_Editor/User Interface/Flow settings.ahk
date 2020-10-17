
ui_SettingsOfFlow()
{
	static
	global maingui, variable
	local pos, tempchecked, tempXpos, tempYpos, tempDir, tempSettingFlowExecutionPolicyOld
	
	maingui.disable()
	gui,5:default
	;~ gui,+owner
	
	gui,-dpiscale
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300,% lang("Flow_execution_policy")
	gui,font,s8 cDefault wnorm
	
	local executionPolicy := _getFlowProperty(FlowID, "flowSettings.ExecutionPolicy")

	if (executionPolicy="default")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsDefault checked%tempchecked%,% lang("Use global setting")
	if (executionPolicy="parallel")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsParallel checked%tempchecked%,% lang("Parallel_execution_of_multiple_instances")
	if (executionPolicy="skip")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsSkip checked%tempchecked% ,% lang("Skip_execution_when_an_instance_is_already_executing")
	if (executionPolicy="wait")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsWait  checked%tempchecked%,% lang("Wait_until_the_currently_executing_instance_has_finished")
	if (executionPolicy="stop")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsStop  checked%tempchecked%,% lang("Stop_the_currently_executing_instance_and_execute_afterwards")
	 
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Working directory")
	gui,font,s8 cDefault wnorm
	
	if (_getFlowProperty(FlowID, "flowSettings.DefaultWorkingDir") = True)
		tempchecked=1
	else
		tempchecked=0
	gui,add,Checkbox,w300 x10 Y+10 vGuiFlowSettingsDefaultWorkingDir checked%tempchecked% gGuiFlowSettingsDefaultWorkingDir,% lang("Use global working dir")
	gui,add,Edit,w300 x10 Y+10 vGuiFlowSettingsWorkingDir disabled%tempchecked%,% _getFlowProperty(FlowID, "flowSettings.WorkingDir")
	
	
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Debug options")
	gui,add,button,w300 x10 h30 Y+10 gGuiFlowSettingsButtonShowLog,% lang("Show log")
	
	gui,add,button,w145 x10 h30 Y+20 gGuiFlowSettingsOK default,% lang("Save")
	gui,add,button,w145 h30 yp X+10 gGuiFlowSettingsCancel,% lang("Cancel")
	

	;Put the window in the center of the main window
	gui,+hwndglobal_SettingWindowHWND
	global_CurrentlyActiveWindowHWND:=global_SettingWindowHWND
	gui,show,hide
	DetectHiddenWindows,on
	
	pos:=EditGUIGetPos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %global_SettingWindowHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	gui,show,x%tempXpos% y%tempYpos%
	return
	
	GuiFlowSettingsButtonShowLog:
	showlog(_getFlowProperty(FlowID, "Name"))
	return
	
	GuiFlowSettingsDefaultWorkingDir:
	gui,submit,NoHide
	if GuiFlowSettingsDefaultWorkingDir
	{
		;todo: warum geht das nicht?
		guicontrol, disable, GuiFlowSettingsWorkingDir
	}
	else
	{
		;todo: warum geht das nicht?
		guicontrol, enable, GuiFlowSettingsWorkingDir
	}
	return
	
	GuiFlowSettingsOK:
	GuiFlowSettingsStayOpen:=false
	someSettingChanged:=false
	
	gui,submit,NoHide
	
	;Check working directory
	if (GuiFlowSettingsDefaultWorkingDir)
	{
		if not (checkNewWorkingDir(GuiFlowSettingsWorkingDir))
		{
			return
		}
		if (GuiFlowSettingsWorkingDir != _getFlowProperty(FlowID, "flowSettings.WorkingDir"))
		{
			someSettingChanged:=true
			_setFlowProperty(FlowID, "flowSettings.WorkingDir", GuiFlowSettingsWorkingDir)
		}
	}
	if (_getFlowProperty(FlowID, "flowSettings.DefaultWorkingDir") != GuiFlowSettingsDefaultWorkingDir)
	{
		someSettingChanged:=true
		_setFlowProperty(FlowID, "flowSettings.DefaultWorkingDir", GuiFlowSettingsDefaultWorkingDir)
	}
	
	if GuiFlowSettingsDefault=1
		tempExecutionPolicy:="default"
	if GuiFlowSettingsParallel=1
		tempExecutionPolicy:="parallel"
	else if GuiFlowSettingsSkip=1
		tempExecutionPolicy:="skip"
	else if GuiFlowSettingsWait=1
		tempExecutionPolicy:="wait"		
	else if GuiFlowSettingsStop=1
		tempExecutionPolicy:="stop"
	
	if (_getFlowProperty(FlowID, "flowSettings.ExecutionPolicy") != tempExecutionPolicy)
	{
		_setFlowProperty(FlowID, "flowSettings.ExecutionPolicy", tempExecutionPolicy)
		someSettingChanged:=true
	}
	
	if someSettingChanged:=true
	{
		State_New(FlowID)
	}
	gui,destroy
	maingui.enable()
	
	return
	
	GuiFlowSettingsCancel:
	
	gui,destroy
	maingui.enable()
	return
	
	
	
}


