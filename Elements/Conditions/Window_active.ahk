iniAllConditions.="Window_Active|" ;Add this condition to list of all conditions on initialisation

runConditionWindow_Active(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	tempWinTitle:=v_replaceVariables(InstanceID,%ElementID%Wintitle)
	tempWinText:=v_replaceVariables(InstanceID,%ElementID%winText)
	tempExcludeTitle:=v_replaceVariables(InstanceID,%ElementID%excludeTitle)
	tempExcludeText:=v_replaceVariables(InstanceID,%ElementID%ExcludeText)
	tempTitleMatchMode :=%ElementID%TitleMatchMode

	tempahk_class:=v_replaceVariables(InstanceID,%ElementID%ahk_class)
	tempahk_exe:=v_replaceVariables(InstanceID,%ElementID%ahk_exe)
	tempahk_id:=v_replaceVariables(InstanceID,%ElementID%ahk_id)
	tempahk_pid:=v_replaceVariables(InstanceID,%ElementID%ahk_pid)
	
	tempwinstring=%tempWinTitle%
	if tempahk_class<>
		tempwinstring=%tempwinstring% ahk_class %tempahk_class%
	if tempahk_id<>
		tempwinstring=%tempwinstring% ahk_id %tempahk_id%
	if tempahk_pid<>
		tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
	if tempahk_exe<>
		tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
	
	
	SetTitleMatchMode,%tempTitleMatchMode%
	
	IfWinActive,%tempwinstring%,%tempWinText%,%tempExcludeTitle%,%tempExcludeText%
	{
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"yes")
	}
	else
	{
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"no")
	}

	return
}
getNameConditionWindow_Active()
{
	return lang("Window_is_active")
}
getCategoryConditionWindow_Active()
{
	return lang("Window")
}

getParametersConditionWindow_Active()
{
	global
	parametersToEdit:=["Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Label|" lang("Exclude_text_of_a_control_in_window"),"text||ExcludeText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Get_parameters"), "button|FunctionsForElementGetWindowInformation||" lang("Get_Parameters")]
	
	return parametersToEdit
}

GenerateNameConditionWindow_Active(ID)
{
	global
	
	tempNameString:=lang("Window_is_active")
	if GUISettingsOfElement%ID%Wintitle<>
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