
ui_SettingsOwFLow()
{
	static
	global maingui, CurrentlyActiveWindowHWND, variable, flowobj
	local pos, tempchecked, tempXpos, tempYpos, tempDir, tempSettingFlowExecutionPolicyOld
	
	maingui.disable()
	gui,5:default
	;~ gui,+owner
	
	gui,-dpiscale
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300,% lang("Flow_execution_policy")
	gui,font,s8 cDefault wnorm
	
	if (flowobj.flowSettings.ExecutionPolicy="default")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsDefault checked%tempchecked%,% lang("Use global setting")
	if (flowobj.flowSettings.ExecutionPolicy="parallel")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsParallel checked%tempchecked%,% lang("Parallel_execution_of_multiple_instances")
	if (flowobj.flowSettings.ExecutionPolicy="skip")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsSkip checked%tempchecked% ,% lang("Skip_execution_when_an_instance_is_already_executing")
	if (flowobj.flowSettings.ExecutionPolicy="wait")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsWait  checked%tempchecked%,% lang("Wait_until_the_currently_executing_instance_has_finished")
	if (flowobj.flowSettings.ExecutionPolicy="stop")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsStop  checked%tempchecked%,% lang("Stop_the_currently_executing_instance_and_execute_afterwards")
	 
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Working directory")
	gui,font,s8 cDefault wnorm
	
	if (flowobj.flowSettings.DefaultWorkingDir=True)
		tempchecked=1
	else
		tempchecked=0
	gui,add,Checkbox,w300 x10 Y+10 vGuiFlowSettingsDefaultWorkingDir checked%tempchecked% gGuiFlowSettingsDefaultWorkingDir,% lang("Use global working dir")
	gui,add,Edit,w300 x10 Y+10 vGuiFlowSettingsWorkingDir disabled%tempchecked%,% flowobj.flowSettings.WorkingDir
	
	
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Debug options")
	gui,add,button,w300 x10 h30 Y+10 gGuiFlowSettingsButtonShowLog,% lang("Show log")
	
	gui,add,button,w145 x10 h30 Y+20 gGuiFlowSettingsOK default,% lang("Save")
	gui,add,button,w145 h30 yp X+10 gGuiFlowSettingsCancel,% lang("Cancel")
	

	;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	DetectHiddenWindows,on
	
	pos:=EditGUIGetPos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	gui,show,x%tempXpos% y%tempYpos%
	return
	
	GuiFlowSettingsButtonShowLog:
	showlog(flowobj.name)
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
		newworkingdir:=checkNewWorkingDir(_settings.FlowWorkingDir, GuiFlowSettingsWorkingDir)
		if not (newworkingdir)
		{
			return
		}
		if (newworkingdir != flowobj.flowSettings.WorkingDir)
		{
			someSettingChanged:=true
			flowobj.flowSettings.WorkingDir :=newworkingdir
		}
	}
	if (flowobj.flowSettings.DefaultWorkingDir != GuiFlowSettingsDefaultWorkingDir)
	{
		someSettingChanged:=true
		flowobj.flowSettings.DefaultWorkingDir := GuiFlowSettingsDefaultWorkingDir
	}
	
	
	tempSettingFlowExecutionPolicyOld:=flowobj.flowSettings.ExecutionPolicy
	
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
	
	if (flowobj.flowSettings.ExecutionPolicy!=tempExecutionPolicy)
	{
		flowobj.flowSettings.ExecutionPolicy:=tempExecutionPolicy
		someSettingChanged:=true
	}
	
	if someSettingChanged:=true
	{
		API_Main_State_New(flowobj.id)
	}
	gui,destroy
	maingui.enable()
	
	return
	
	GuiFlowSettingsCancel:
	
	gui,destroy
	maingui.enable()
	return
	
	
	
}


