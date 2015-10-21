;Default settings
SettingFlowExecutionPolicy=parallel

ui_SettingsOwFLow()
{
	global
	
	ui_DisableMainGUI()
	gui,5:default
	;~ gui,+owner
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300,% lang("Flow_execution_policy")
	
	gui,font,s8 cDefault wnorm
	
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
	 
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Working directory")
	gui,font,s8 cDefault wnorm
	gui,add,Edit,w300 x10 Y+10 vGuiFlowSettingsWorkingDir,% SettingWorkingDir
	
	
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w300 Y+15,% lang("Debug options")
	gui,font,s8 cDefault wnorm
	if SettingFlowLogToFile=1
		tempchecked=1
	gui,add,Checkbox,w300 x10 Y+10 vGuiFlowSettingsLogToFile checked%tempchecked% ,% lang("Log to file")
	gui,add,button,w300 x10 h30 Y+10 gGuiFlowSettingsButtonShowLog,% lang("Show log")
	
	gui,add,button,w145 x10 h30 Y+20 gGuiFlowSettingsOK default,% lang("Save")
	gui,add,button,w145 h30 yp X+10 gGuiFlowSettingsCancel,% lang("Cancel")
	

		;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	
	ui_GetMainGUIPos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(MainGUIX+MainGUIWidth/2- tempWidth/2)
	tempYpos:=round(MainGUIY+MainGUIHeight/2- tempHeight/2)
	gui,show,x%tempXpos% y%tempYpos%
	return
	
	GuiFlowSettingsButtonShowLog:
	showlog()
	return
	
	
	
	GuiFlowSettingsOK:
	GuiFlowSettingsStayOpen:=false
	tempSettingFlowExecutionPolicyOld:=SettingFlowExecutionPolicy
	
	gui,submit,NoHide
	if GuiFlowSettingsParallel=1
		SettingFlowExecutionPolicy=parallel
	else if GuiFlowSettingsSkip=1
		SettingFlowExecutionPolicy=skip
	else if GuiFlowSettingsWait=1
		SettingFlowExecutionPolicy=wait		
	else if GuiFlowSettingsStop=1
		SettingFlowExecutionPolicy=stop
	
	SettingFlowLogToFile:=GuiFlowSettingsLogToFile
	
	if (tempSettingFlowExecutionPolicyOld!=SettingFlowExecutionPolicy)
		saved=no
	
	
	tempDir:=% v_replaceVariables(InstanceID,ThreadID,GuiFlowSettingsWorkingDir) ;if user entered a built in variable
	if DllCall("Shlwapi.dll\PathIsRelative","Str",tempDir) ;if user did not enter an absolute path
	{
		if GuiFlowSettingsWorkingDir!=  ;If user left it blank, he don't want to change it. if not...
		{
			MsgBox, 17, AutoHotFlow, % lang("The specified folder is not an absolute path!") "`n" lang("If you press '%1%', previous path will remain.",lang("OK"))
			IfMsgBox cancel
				GuiFlowSettingsStayOpen:=true
		}
	}
	else
	{
		if not FileExist(GuiFlowSettingsWorkingDir)
		{
			MsgBox, 35, AutoHotFlow, % lang("The specified folder does not exist. Should it be created?") "`n" lang("If you press '%1%', previous path will remain.",lang("No"))
			IfMsgBox Yes
			{
				FileCreateDir,%GuiFlowSettingsWorkingDir%
				if errorlevel
				{
					
					MsgBox, 16, AutoHotFlow, % lang("The specified folder could not be created!")
					GuiFlowSettingsStayOpen:=true
				}
				else
				{
					SettingWorkingDir:=GuiFlowSettingsWorkingDir
					saved=no
				}
				
			}
			else IfMsgBox cancel
				GuiFlowSettingsStayOpen:=true
		}
		else
		{
			SettingWorkingDir:=GuiFlowSettingsWorkingDir
			saved=no
		}
	}
	
	if not GuiFlowSettingsStayOpen
	{
		gui,destroy
		ui_EnableMainGUI()
	}
	return
	
	GuiFlowSettingsCancel:
	
	gui,destroy
	ui_EnableMainGUI()
	return
	
	
	
}


