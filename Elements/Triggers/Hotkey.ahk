iniAllTriggers.="Hotkey|" ;Add this trigger to list of all triggers on initialisation


EnableTriggerHotkey(ElementID)
{
	global
	
	temphotkey:=%ElementID%hotkey
	if temphotkey=
	{
		MsgBox,% lang("Error. The_Hotkey_is_not_set!")
		return
	}
	if (%ElementID%BlockKey=0)
		temphotkey=~%temphotkey%
	if (%ElementID%WhenRelease=1)
		temphotkey=%temphotkey% UP
	
	
	if (%ElementID%UseWindow =2 or %ElementID%UseWindow =3)
	{
		tempWinTitle:=v_replaceVariables(0,0,%ElementID%Wintitle)
		tempWinText:=v_replaceVariables(0,0,%ElementID%winText)
		tempExcludeTitle:=v_replaceVariables(0,0,%ElementID%excludeTitle)
		tempExcludeText:=v_replaceVariables(0,0,%ElementID%ExcludeText)
		tempTitleMatchMode :=%ElementID%TitleMatchMode
		tempahk_class:=v_replaceVariables(0,0,%ElementID%ahk_class)
		tempahk_exe:=v_replaceVariables(0,0,%ElementID%ahk_exe)
		tempahk_id:=v_replaceVariables(0,0,%ElementID%ahk_id)
		tempahk_pid:=v_replaceVariables(0,0,%ElementID%ahk_pid)
		
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
	}


	
	if (%ElementID%UseWindow =2)
		hotkey,IfWinActive,%tempwinstring%,%tempWinText% ;,%tempExcludeTitle%,%tempExcludeText%
	else if (%ElementID%UseWindow =3)
		hotkey,IfWinExist,%tempwinstring%,%tempWinText% ;,%tempExcludeTitle%,%tempExcludeText%
	else
		hotkey,IfWinActive
	
	hotkey,%temphotkey%,r_startRun, UseErrorLevel on
	if ErrorLevel
	{
		MsgBox,% lang("Error. The hotkey %1% cannot be set!",temphotkey)
	}
	%ElementID%enabledHotkey:=temphotkey
	
	
}


getParametersTriggerHotkey()
{
	
	parametersToEdit:=["Label|" lang("Select_Hotkey"),"Hotkey||hotkey","Checkbox|1|BlockKey|" lang("Block_key"),"Checkbox|0|WhenRelease|" lang("Trigger on release"),"Label|" lang("Window"),"Radio|1|UseWindow|" lang("Always active") ";" lang("Only active when the specified window is active") ";" lang("Only active whe the specified window exists"),"Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Get_parameters"), "button|FunctionsForElementGetWindowInformation|GetWindowInformation|" lang("Get_Parameters")]

	
	
	return parametersToEdit
}

getNameTriggerHotkey()
{
	return lang("Hotkey")
}
getCategoryTriggerHotkey()
{
	return lang("User_interaction")
}

DisableTriggerHotkey(ID)
{
	
	temphotkey:=%ID%enabledHotkey
	hotkey,%temphotkey%,r_startRun,UseErrorLevel off
	
	
}

GenerateNameTriggerHotkey(ID)
{
	return lang("Hotkey") ": " GUISettingsOfElement%ID%hotkey
	
}

CheckSettingsTriggerHotkey(ID)
{
	
	if (GUISettingsOfElement%ID%UseWindow2=1 or GUISettingsOfElement%ID%UseWindow3=1)
		tempenable:=1
	else
		tempenable:=0
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%TitleMatchMode1 ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%TitleMatchMode2 ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%TitleMatchMode3 ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%Wintitle ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%excludeTitle ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%winText ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%ExcludeText ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%ahk_class ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%ahk_exe ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%ahk_id ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%ahk_pid ;Deactivate this option
	GuiControl,Enable%tempenable%,GUISettingsOfElement%ID%GetWindowInformation ;Deactivate this option
}
