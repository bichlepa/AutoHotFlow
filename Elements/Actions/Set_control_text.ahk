iniAllActions.="Set_control_text|" ;Add this action to list of all actions on initialisation

runActionSet_control_text(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Wintitle)
	local tempExcludeTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%excludeTitle)
	local tempTitleMatchMode :=%ElementID%TitleMatchMode
	local tempahk_class:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_class)
	local tempahk_exe:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_exe)
	local tempahk_id:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_id)
	local tempahk_pid:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_pid)
	local tempID
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text)
	
	local tempwinstring=%tempWinTitle%
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
	
	if (%ElementID%ControlTextMatchMode) 
			tempControlMatchMode:=1
		else if (%ElementID%ControlTextMatchMode) 
			tempControlMatchMode:=2
		else (%ElementID%ControlTextMatchMode) 
			tempControlMatchMode:=3
	
	SetTitleMatchMode,%tempTitleMatchMode%
	WinGet,tempID,ID,%tempwinstring%,%tempWinText%,%tempExcludeTitle%,%tempExcludeText%
	if tempID ;If a window was found
	{
		
		SetTitleMatchMode,%tempControlMatchMode%
		
		ControlSetText,% v_replaceVariables(InstanceID,ThreadID,%ElementID%Control_identifier,"normal"),% tempText,ahk_id %tempID%
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
	{
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	}
	

	return
}
getNameActionSet_control_text()
{
	return lang("Set_control_text")
}
getCategoryActionSet_control_text()
{
	return lang("Window")
}

getParametersActionSet_control_text()
{
	global
	parametersToEdit:=["Label|" lang("Text to set"),"Text||Text","Label|" lang("Method_for_control_Identification"),"Radio|1|IdentifyControlBy|" lang("Text_in_control") ";" lang("Classname and instance number of the control"),"Label|" lang("Control_Identification")"|Label_Control_Identification","Radio|2|ControlTextMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Control_identifier","Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","button|FunctionsForElementGetControlInformation||" lang("Wizard_to_get_parameters")]
	;,"Label|" lang("Insert_a_keystroke"), "Hotkey||HotkeyToInsert,"Button|customSettingButtonOfActionSet_control_textHotkeyToInsert||" lang("Insert")
	return parametersToEdit
}


GenerateNameActionSet_control_text(ID)
{
	global
	
	return % lang("Set_control_text")  "`n" GUISettingsOfElement%ID%KeysToSend "`n" lang("Control") ": " GUISettingsOfElement%ID%Control_identifier
	
}


CheckSettingsActionSet_control_text(ID)
{
	;MsgBox % "GUISettingsOfElement%ID%IdentifyControlBy " GUISettingsOfElement%ID%IdentifyControlBy
	if (GUISettingsOfElement%ID%IdentifyControlBy1 = 1)
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode1
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode2
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode3
		GuiControl,,GUISettingsOfElement%ID%Label_Control_Identification,% lang("Text_in_control")
	}
	else
	{
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode1
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode2
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode3
		GuiControl,,GUISettingsOfElement%ID%Label_Control_Identification,% lang("Classname and instance number of the control")
	}
	
}
