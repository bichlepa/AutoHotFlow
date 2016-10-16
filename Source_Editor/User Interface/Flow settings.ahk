
ui_SettingsOwFLow()
{
	static
	global maingui, share, CurrentlyActiveWindowHWND, variable
	local pos, tempchecked, tempXpos, tempYpos, tempDir, tempSettingFlowExecutionPolicyOld
	
	maingui.disable()
	gui,5:default
	;~ gui,+owner
	
	gui,-dpiscale
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300,% lang("Flow_execution_policy")
	
	gui,font,s8 cDefault wnorm
	
	if (share.flowSettings.ExecutionPolicy="parallel")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsParallel checked%tempchecked%,% lang("Parallel_execution_of_multiple_instances")
	if (share.flowSettings.ExecutionPolicy="skip")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsSkip checked%tempchecked% ,% lang("Skip_execution_when_an_instance_is_already_executing")
	if (share.flowSettings.ExecutionPolicy="wait")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsWait  checked%tempchecked%,% lang("Wait_until_the_currently_executing_instance_has_finished")
	if (share.flowSettings.ExecutionPolicy="stop")
		tempchecked=1
	else
		tempchecked=0
	gui,add,radio,w300 x10 Y+10 vGuiFlowSettingsStop  checked%tempchecked%,% lang("Stop_the_currently_executing_instance_and_execute_afterwards")
	 
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Working directory")
	gui,font,s8 cDefault wnorm
	gui,add,Edit,w300 x10 Y+10 vGuiFlowSettingsWorkingDir,% share.flowSettings.WorkingDir
	
	
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Debug options")
	gui,font,s8 cDefault wnorm
	if (share.flowSettings.LogToFile=1)
		tempchecked=1
	else
		tempchecked=0
	gui,add,Checkbox,w300 x10 Y+10 vGuiFlowSettingsLogToFile checked%tempchecked% ,% lang("Log to file")
	gui,add,button,w300 x10 h30 Y+10 gGuiFlowSettingsButtonShowLog,% lang("Show log")
	
	gui,add,button,w145 x10 h30 Y+20 gGuiFlowSettingsOK default,% lang("Save")
	gui,add,button,w145 h30 yp X+10 gGuiFlowSettingsCancel,% lang("Cancel")
	

		;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	
	pos:=maingui.getpos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	gui,show,x%tempXpos% y%tempYpos%
	return
	
	GuiFlowSettingsButtonShowLog:
	;~ showlog()
	return
	
	
	
	GuiFlowSettingsOK:
	GuiFlowSettingsStayOpen:=false
	someSettingChanged:=false
	
	gui,submit,NoHide
	
	
	;~ d(variable)
	tempDir:=% variable.replaceVariables("",GuiFlowSettingsWorkingDir) ;if user entered a built in variable
	if DllCall("Shlwapi.dll\PathIsRelative","Str",tempDir) ;if user did not enter an absolute path
	{
		if GuiFlowSettingsWorkingDir!=  ;If user left it blank, he don't want to change it. if not...
		{
			MsgBox, 17, AutoHotFlow, % lang("The specified folder is not an absolute path!") "`n" lang("If you press '%1%', previous path will remain.",lang("OK"))
			IfMsgBox cancel
				return
		}
	}
	else
	{
		if not FileExist(GuiFlowSettingsWorkingDir)
		{
			MsgBox, 36, AutoHotFlow, % lang("The specified folder does not exist. Should it be created?") "`n" lang("Press '%1%', if you want to correct it.",lang("No"))
			IfMsgBox Yes
			{
				FileCreateDir,%GuiFlowSettingsWorkingDir%
				if errorlevel
				{
					MsgBox, 16, AutoHotFlow, % lang("The specified folder could not be created!")
					return
				}
				else
				{
					share.flowSettings.WorkingDir:=GuiFlowSettingsWorkingDir
					someSettingChanged:=true
				}
				
			}
			else
				return
		}
		else
		{
			share.flowSettings.WorkingDir:=GuiFlowSettingsWorkingDir
			someSettingChanged:=true
		}
	}
	
	
	tempSettingFlowExecutionPolicyOld:=share.flowSettings.ExecutionPolicy
	
	if GuiFlowSettingsParallel=1
		tempExecutionPolicy:="parallel"
	else if GuiFlowSettingsSkip=1
		tempExecutionPolicy:="skip"
	else if GuiFlowSettingsWait=1
		tempExecutionPolicy:="wait"		
	else if GuiFlowSettingsStop=1
		tempExecutionPolicy:="stop"
	
	if (share.flowSettings.ExecutionPolicy!=tempExecutionPolicy)
	{
		share.flowSettings.ExecutionPolicy:=tempExecutionPolicy
		someSettingChanged:=true
	}
	
	if (share.flowSettings.LogToFile!=GuiFlowSettingsLogToFile)
	{
		share.flowSettings.LogToFile:=GuiFlowSettingsLogToFile
		someSettingChanged:=true
	}
	
	if someSettingChanged:=true
	{
		new state()
	}
	gui,destroy
	maingui.enable()
	
	return
	
	GuiFlowSettingsCancel:
	
	gui,destroy
	maingui.enable()
	return
	
	
	
}


