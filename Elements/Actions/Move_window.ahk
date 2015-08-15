iniAllActions.="Move_window|" ;Add this action to list of all actions on initialisation

runActionMove_window(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempWinid
	
	local tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Wintitle)
	local tempExcludeTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%excludeTitle)
	local tempWinText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%winText)
	local tempExcludeText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ExcludeText)
	local tempTitleMatchMode :=%ElementID%TitleMatchMode
	local tempahk_class:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_class)
	local tempahk_exe:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_exe)
	local tempahk_id:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_id)
	local tempahk_pid:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_pid)
	
	local tempwinstring:=tempWinTitle
	if tempahk_class<>
		tempwinstring=%tempwinstring% ahk_class %tempahk_class%
	if tempahk_id<>
		tempwinstring=%tempwinstring% ahk_id %tempahk_id%
	if tempahk_pid<>
		tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
	if tempahk_exe<>
		tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
	if tempwinstring=
		tempwinstring=A
	
	SetTitleMatchMode,%tempTitleMatchMode%
	
	if %ElementID%findhiddenwindow=0
		DetectHiddenWindows off
	else
		DetectHiddenWindows on
	if %ElementID%findhiddentext=0
		DetectHiddenText off
	else
		DetectHiddenText on
	
	
	tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText)
	If not tempWinid
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Seeked window does not exist")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Seeked window does not exist"))
		return
		
	}
	
	
	
	v_SetVariable(InstanceID,ThreadID,"A_WindowID",tempWinid,,c_SetBuiltInVar)
	if %ElementID%WinMoveEvent=1
		WinMaximize,ahk_id %tempWinid%
	else if %ElementID%WinMoveEvent=2
		WinMinimize,ahk_id %tempWinid%
	else if %ElementID%WinMoveEvent=3
		WinRestore,ahk_id %tempWinid%
	else if %ElementID%WinMoveEvent=4
	{
		local Xpos:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%Xpos)
		local Ypos:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%Ypos)
		local Width:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%Width)
		local Height:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%Height)
		local countNotANumber=0
		
		if Xpos is not number
		{
			countNotANumber++
			if Xpos!=
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! X position is set but is not a number.")
				xpos=
			}
		}
		if Ypos is not number
		{
			countNotANumber++
			if Ypos!=
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Y position is set but is not a number.")
				Ypos=
			}
		}
		if Width is not number
		{
			countNotANumber++
			if Width!=
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Width is set but is not a number.")
				Width=
			}
		}
		if Height is not number
		{
			countNotANumber++
			if Height!=
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Height is set but is not a number.")
				Height=
			}
		}
		
		if countNotANumber=4
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No position specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No position specified."))
			return
			
		}
		
		Winmove,ahk_id %tempWinid%,,% Xpos,% Ypos,% Width,% Height
		
		
		
		
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	

	
	return
}
getNameActionMove_window()
{
	return lang("Move_window")
}
getCategoryActionMove_window()
{
	return lang("Window")
}

getParametersActionMove_window()
{
	global
	parametersToEdit:=["Label|" lang("Event") ,"Radio|1|WinMoveEvent|" lang("Maximize") ";" lang("Minimize") ";" lang("Restore") ";" lang("Move"),"Label|" lang("Coordinates") " " lang("(x,y)"),"Text2|;|Xpos;Ypos","Label|" lang("Width and height"),"Text2|;|Width;Height","Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Checkbox|0|FindHiddenText|" lang("Detect hidden text"),"Label|" lang("Exclude_text_of_a_control_in_window"),"text||ExcludeText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Hidden window"),"Checkbox|0|FindHiddenWindow|" lang("Detect hidden window"),"Label|" lang("Get_parameters"), "button|FunctionsForElementGetWindowInformation||" lang("Get_Parameters")]
	
	return parametersToEdit
}

GenerateNameActionMove_window(ID)
{
	global
	
	tempNameString:=lang("Move_window")
	if GUISettingsOfElement%ID%Wintitle!=
	{
		
		if GUISettingsOfElement%ID%TitleMatchMode1=1
			tempNameString:=tempNameString "`n" lang("Title begins with") ": " GUISettingsOfElement%ID%Wintitle
		else if GUISettingsOfElement%ID%TitleMatchMode2=1
			tempNameString:=tempNameString "`n" lang("Title includes") ": " GUISettingsOfElement%ID%Wintitle
		else if if GUISettingsOfElement%ID%TitleMatchMode3=1
			tempNameString:=tempNameString "`n" lang("Title is exatly") ": " GUISettingsOfElement%ID%Wintitle
		
		
	}
	if GUISettingsOfElement%ID%excludeTitle<>
		tempNameString:=tempNameString "`n" lang("Exclude_title") ": " GUISettingsOfElement%ID%excludeTitle
	if GUISettingsOfElement%ID%winText<>
		tempNameString:=tempNameString "`n" lang("Control_text") ": " GUISettingsOfElement%ID%winText
	if GUISettingsOfElement%ID%ExcludeText<>
		tempNameString:=tempNameString "`n" lang("Exclude_control_text") ": " GUISettingsOfElement%ID%ExcludeText
	if GUISettingsOfElement%ID%ahk_class<>
		tempNameString:=tempNameString "`n" lang("Window_Class") ": " GUISettingsOfElement%ID%ahk_class
	if GUISettingsOfElement%ID%ahk_exe<>
		tempNameString:=tempNameString "`n" lang("Process") ": " GUISettingsOfElement%ID%ahk_exe
	if GUISettingsOfElement%ID%ahk_id<>
		tempNameString:=tempNameString "`n" lang("Window_ID") ": " GUISettingsOfElement%ID%ahk_id
	if GUISettingsOfElement%ID%ahk_pid<>
		tempNameString:=tempNameString "`n" lang("Process_ID") ": " GUISettingsOfElement%ID%ahk_pid
	
	
	return tempNameString
	
}

CheckSettingsActionMove_window(ID)
{
	if (GUISettingsOfElement%ID%WinMoveEvent4 != 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Xpos
		GuiControl,Disable,GUISettingsOfElement%ID%ypos
		GuiControl,Disable,GUISettingsOfElement%ID%Width
		GuiControl,Disable,GUISettingsOfElement%ID%Height
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Xpos
		GuiControl,Enable,GUISettingsOfElement%ID%ypos
		GuiControl,Enable,GUISettingsOfElement%ID%Width
		GuiControl,Enable,GUISettingsOfElement%ID%Height
	}
	
	
}