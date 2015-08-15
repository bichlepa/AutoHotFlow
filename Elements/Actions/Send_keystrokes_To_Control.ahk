iniAllActions.="Send_Keystrokes_To_Control|" ;Add this action to list of all actions on initialisation

runActionSend_Keystrokes_To_Control(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Wintitle)
	local tempExcludeTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%excludeTitle)
	local tempWinText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%winText)
	local tempExcludeText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ExcludeText)
	local tempTitleMatchMode :=%ElementID%TitleMatchMode
	local tempControlTextMatchMode :=%ElementID%ControlTextMatchMode
	local tempahk_class:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_class)
	local tempahk_exe:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_exe)
	local tempahk_id:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_id)
	local tempahk_pid:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_pid)
	local tempWinid
	
	local tempControl_identifier:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Control_identifier)
	local tempKeysToSend:=v_replaceVariables(InstanceID,ThreadID,%ElementID%KeysToSend)
	
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
	
	WinGet,tempWinid,ID,%tempwinstring%,%tempWinText%,%tempExcludeTitle%,%tempExcludeText%
	
	if tempWinid=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Seeked window does not exist")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Seeked window does not exist"))
		return
	}
	
	
	SetTitleMatchMode,%tempControlTextMatchMode%
	
	controlget,tempControlID,hwnd,,% tempControl_identifier,ahk_id %tempWinid%
	if tempControlID=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Seeked control does not exist")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Seeked control does not exist"))
		return
		
	}
	
	
	
	if %ElementID%RawMode=1
		ControlSendraw,,% tempKeysToSend,ahk_id %tempControlID%
	else
		ControlSend,,% tempKeysToSend,ahk_id %tempControlID%
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	

	return
}
getNameActionSend_Keystrokes_To_Control()
{
	return lang("Send Keystrokes to a control")
}
getCategoryActionSend_Keystrokes_To_Control()
{
	return lang("User_simulation") "|" lang("Window")
}

getParametersActionSend_Keystrokes_To_Control()
{
	global
	parametersToEdit:=["Label|" lang("Keys_or_text_to_send"),"Checkbox|0|RawMode|" lang("Raw mode"),"Text||KeysToSend","Label|" lang("Method_for_control_Identification"),"Radio|1|IdentifyControlBy|" lang("Text_in_control") ";" lang("Classname and instance number of the control"),"Label|" lang("Control_Identification")"|Label_Control_Identification","Radio|2|ControlTextMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Control_identifier","Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Checkbox|0|FindHiddenText|" lang("Detect hidden text"),,"Label|" lang("Exclude_text_of_a_control_in_window"),"text||ExcludeText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Hidden window"),"Checkbox|0|FindHiddenWindow|" lang("Detect hidden window"),"button|FunctionsForElementGetControlInformation||" lang("Wizard_to_get_parameters")]
	;,"Label|" lang("Insert_a_keystroke"), "Hotkey||HotkeyToInsert,"Button|customSettingButtonOfActionSend_Keystrokes_To_ControlHotkeyToInsert||" lang("Insert")
	return parametersToEdit
}


GenerateNameActionSend_Keystrokes_To_Control(ID)
{
	global
	
	return % lang("Send Keystrokes to a control")  "`n" GUISettingsOfElement%ID%KeysToSend "`n" lang("Control") ": " GUISettingsOfElement%ID%Control_identifier
	
}


CheckSettingsActionSend_Keystrokes_To_Control(ID)
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
