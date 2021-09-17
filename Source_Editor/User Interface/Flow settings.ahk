
; opens a gui where user can edit the flow settings
ui_SettingsOfFlow()
{
	global
	local pos, tempchecked, tempXpos, tempYpos, tempDir, tempSettingFlowExecutionPolicyOld
	
	; disable editor gui
	EditGUIDisable()

	; create gui
	gui, FlowSettings: default
	gui, -dpiscale

	; show flow execution policy options
	gui, font, s10 cnavy wbold
	gui, add, text, x10 w300, % lang("Flow_execution_policy")
	gui, font, s8 cDefault wnorm
	
	; get current setting
	local executionPolicy := _getFlowProperty(_FlowID, "flowSettings.ExecutionPolicy")
	; add the radio buttons and check the selected option
	if (executionPolicy = "default")
		tempchecked := 1
	else
		tempchecked := 0
	gui, add, radio, w300 x10 Y+10 vGuiFlowSettingsDefault checked%tempchecked%, % lang("Use global setting")
	if (executionPolicy = "parallel")
		tempchecked := 1
	else
		tempchecked := 0
	gui, add, radio, w300 x10 Y+10 vGuiFlowSettingsParallel checked%tempchecked%, % lang("Parallel_execution_of_multiple_instances")
	if (executionPolicy = "skip")
		tempchecked := 1
	else
		tempchecked := 0
	gui, add, radio, w300 x10 Y+10 vGuiFlowSettingsSkip checked%tempchecked%, % lang("Skip_execution_when_an_instance_is_already_executing")
	if (executionPolicy = "wait")
		tempchecked := 1
	else
		tempchecked := 0
	gui, add, radio, w300 x10 Y+10 vGuiFlowSettingsWait checked%tempchecked%, % lang("Wait_until_the_currently_executing_instance_has_finished")
	if (executionPolicy = "stop")
		tempchecked := 1
	else
		tempchecked := 0
	gui, add, radio, w300 x10 Y+10 vGuiFlowSettingsStop checked%tempchecked%, % lang("Stop_the_currently_executing_instance_and_execute_afterwards")

	; show working directory option
	gui, font, s10 cnavy wbold
	gui, add, text, x10 w300 Y+15, % lang("Working directory")
	gui, font, s8 cDefault wnorm
	
	if (_getFlowProperty(_FlowID, "flowSettings.DefaultWorkingDir"))
		tempchecked := 1
	else
		tempchecked := 0
	gui, add, Checkbox, w300 x10 Y+10 vGuiFlowSettingsDefaultWorkingDir checked%tempchecked% gGuiFlowSettingsDefaultWorkingDir, % lang("Use global working dir")
	gui, add, Edit, w300 x10 Y+10 r3 vGuiFlowSettingsWorkingDir disabled%tempchecked%, % _getFlowProperty(_FlowID, "flowSettings.WorkingDir")
	
	; show debug options
	gui, font, s10 cnavy wbold
	gui, add, text, x10 w300 Y+15, % lang("Debug options")
	gui, add, button, w300 x10 h30 Y+10 gGuiFlowSettingsButtonShowLog, % lang("Show log")
	
	; add save and cancel buttons
	gui, add, button, w145 x10 h30 Y+20 gGuiFlowSettingsOK default, % lang("Save #verb")
	gui, add, button, w145 h30 yp X+10 gGuiFlowSettingsCancel, % lang("Cancel")
	

	;Put the window in the center of the main window
	gui, +hwndglobal_SettingWindowHWND
	global_CurrentlyActiveWindowHWND := global_SettingWindowHWND
	gui, show, hide
	DetectHiddenWindows, on
	
	; Calculate gui position. We want to show the settings window in the middle of the main window
	local pos := EditGUIGetPos()
	local tempWidth, tempHeight
	wingetpos,,,tempWidth,tempHeight,ahk_id %global_SettingWindowHWND%
	local tempXpos := round(pos.x + pos.w / 2 - tempWidth / 2)
	local tempYpos := round(pos.y + pos.h / 2 - tempHeight / 2)

	; move gui to the calculated position
	gui, show, x%tempXpos% y%tempYpos%
	return
	
	; react if user wants to show the log
	GuiFlowSettingsButtonShowLog:
	showlog(_getFlowProperty(_FlowID, "Name"))
	return
	
	; react if user changes the working directory
	GuiFlowSettingsDefaultWorkingDir:
	; get content from gui
	gui, submit, NoHide

	; disable edit field if default derectory checkbox is checked
	if (GuiFlowSettingsDefaultWorkingDir)
	{
		guicontrol, disable, GuiFlowSettingsWorkingDir
	}
	else
	{
		guicontrol, enable, GuiFlowSettingsWorkingDir
	}
	return
	
	; react if user clicks on the OK button
	GuiFlowSettingsOK:

	; we will write true, if we find a change
	someSettingChanged := false
	
	; get content from gui
	gui, submit, NoHide
	
	;Check working directory
	if (not GuiFlowSettingsDefaultWorkingDir)
	{
		; check working directory (in interactive mode)
		if (not checkNewWorkingDir(GuiFlowSettingsWorkingDir, true))
		{
			; the working directory is invalid. User has to set it.
			return
		}

		; check whether parameter WorkingDir changed
		if (GuiFlowSettingsWorkingDir != _getFlowProperty(_FlowID, "flowSettings.WorkingDir"))
		{
			; write the changed value
			someSettingChanged := true
			_setFlowProperty(_FlowID, "flowSettings.WorkingDir", GuiFlowSettingsWorkingDir)
		}
	}

	; check whether parameter DefaultWorkingDir changed
	if (_getFlowProperty(_FlowID, "flowSettings.DefaultWorkingDir") != GuiFlowSettingsDefaultWorkingDir)
	{
		; write the changed value
		someSettingChanged := true
		_setFlowProperty(_FlowID, "flowSettings.DefaultWorkingDir", GuiFlowSettingsDefaultWorkingDir)
	}
	
	; find the selected execution policy
	if GuiFlowSettingsDefault
		tempExecutionPolicy := "default"
	if GuiFlowSettingsParallel
		tempExecutionPolicy := "parallel"
	else if GuiFlowSettingsSkip
		tempExecutionPolicy := "skip"
	else if GuiFlowSettingsWait
		tempExecutionPolicy := "wait"		
	else if GuiFlowSettingsStop
		tempExecutionPolicy := "stop"
	
	; check whether parameter ExecutionPolicy changed
	if (_getFlowProperty(_FlowID, "flowSettings.ExecutionPolicy") != tempExecutionPolicy)
	{
		; write the changed value
		_setFlowProperty(_FlowID, "flowSettings.ExecutionPolicy", tempExecutionPolicy)
		someSettingChanged := true
	}
	
	if someSettingChanged := true
	{
		; a parameter has changed. Create a new state.
		State_New(_FlowID)
	}

	; destroy gui and enable editor gui
	gui, destroy
	EditGUIEnable()
	return
	
	; react if user clicks on the Cancel button
	GuiFlowSettingsCancel:
	
	; destroy gui and enable editor gui
	gui, destroy
	EditGUIEnable()
	return
}


