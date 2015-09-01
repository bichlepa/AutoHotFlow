iniAllConditions.="Window_Exists|" ;Add this condition to list of all conditions on initialisation

runConditionWindow_Exists(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Wintitle)
	tempWinText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%winText)
	tempExcludeTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%excludeTitle)
	tempExcludeText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ExcludeText)
	tempTitleMatchMode :=%ElementID%TitleMatchMode
	tempahk_class:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_class)
	tempahk_exe:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_exe)
	tempahk_id:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_id)
	tempahk_pid:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_pid)
	
	tempwinstring=%tempWinTitle%
	if tempahk_class<>
		tempwinstring=%tempwinstring% ahk_class %tempahk_class%
	if tempahk_id<>
		tempwinstring=%tempwinstring% ahk_id %tempahk_id%
	if tempahk_pid<>
		tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
	if tempahk_exe<>
		tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
	;If no active window, unlike in other actions, do not check whether the active window is active, instead error
	if (tempwinstring="" and tempWinText="" and tempExcludeTitle = "" and tempExcludeText ="") 
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No window specified")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("No window specified"))
		return
	}
	
	SetTitleMatchMode,%tempTitleMatchMode%
	
	if %ElementID%findhiddenwindow=0
		DetectHiddenWindows off
	else
		DetectHiddenWindows on
	if %ElementID%findhiddentext=0
		DetectHiddenText off
	else
		DetectHiddenText on
	
	SetTitleMatchMode,%tempTitleMatchMode%

	tempWinid:=WinActive(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText)
	If not tempWinid
	{
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		return
		
	}
	else
	{
		v_SetVariable(InstanceID,ThreadID,"A_WindowID",tempWinid,,c_SetBuiltInVar)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		return
		
	}
	
	
	return
}
getNameConditionWindow_Exists()
{
	return lang("Window_exists")
}
getCategoryConditionWindow_Exists()
{
	return lang("Window")
}

getParametersConditionWindow_Exists()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title")})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window")})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class")})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name")})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Get_parameters")})
	parametersToEdit.push({type: "button", goto: "FunctionsForElementGetWindowInformation", label: lang("Get_Parameters")})

	return parametersToEdit
}

GenerateNameConditionWindow_Exists(ID)
{
	global
	
	tempNameString:=lang("Window_exists")
	if GUISettingsOfElement%ID%Wintitle<>
	{
		
		if GUISettingsOfElement%ID%TitleMatchMode1=1
			tempNameString:=tempNameString "`n" lang("Title begins with") ": " GUISettingsOfElement%ID%Wintitle
		else if GUISettingsOfElement%ID%TitleMatchMode2=1
			tempNameString:=tempNameString "`n" lang("Title includes") ": " GUISettingsOfElement%ID%Wintitle
		else if GUISettingsOfElement%ID%TitleMatchMode3=1
			tempNameString:=tempNameString "`n" lang("Title is exatly") ": " GUISettingsOfElement%ID%Wintitle
		
		
	}
	if GUISettingsOfElement%ID%excludeTitle<>
		tempNameString:=tempNameString "`n" lang("Exclude_title") ": " GUISettingsOfElement%ID%excludeTitle
	if GUISettingsOfElement%ID%winText<>
		tempNameString:=tempNameString "`n" lang("Control_text") ": " GUISettingsOfElement%ID%winText
	if GUISettingsOfElement%ID%ExcludeText<>
		tempNameString:=tempNameString "`n" lang("Exclude_control_text") ": " GUISettingsOfElement%ID%ExcludeText
	if GUISettingsOfElement%ID%tempahk_class<>
		tempNameString:=tempNameString "`n" lang("Window_Class") ": " GUISettingsOfElement%ID%ahk_class
	if GUISettingsOfElement%ID%ahk_exe<>
		tempNameString:=tempNameString "`n" lang("Process") ": " GUISettingsOfElement%ID%ahk_exe
	if GUISettingsOfElement%ID%ahk_id<>
		tempNameString:=tempNameString "`n" lang("Window_ID") ": " GUISettingsOfElement%ID%ahk_id
	if GUISettingsOfElement%ID%ahk_pid<>
		tempNameString:=tempNameString "`n" lang("Process_ID") ": " GUISettingsOfElement%ID%ahk_pid
	
	
	return tempNameString
	

	
}