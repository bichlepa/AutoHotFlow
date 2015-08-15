iniAllActions.="Get_control_text|" ;Add this action to list of all actions on initialisation

runActionGet_control_text(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
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
	
	local tempText	
	local tempControl_identifier:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Control_identifier)
	
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
	;~ MsgBox %tempControlTextMatchMode%
	SetTitleMatchMode,%tempControlTextMatchMode%
	
	controlget,tempControlID,hwnd,,% tempControl_identifier,ahk_id %tempWinid%
	if tempControlID=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Seeked control does not exist")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Seeked control does not exist"))
		return
		
	}
	
	ControlGetText,tempText,,ahk_id %tempControlID%
	v_SetVariable(InstanceID,ThreadID,varname,tempText)
	v_SetVariable(InstanceID,ThreadID,"A_WindowID",tempWinid,,c_SetBuiltInVar)
	v_SetVariable(InstanceID,ThreadID,"A_ControlID",tempControlID,,c_SetBuiltInVar)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	

	return
}
getNameActionGet_control_text()
{
	return lang("Get_control_text")
}
getCategoryActionGet_control_text()
{
	return lang("Window")
}

getParametersActionGet_control_text()
{
	global
	parametersToEdit:=["Label|" lang("Output variable_name"),"VariableName|NewVariable|Varname","Label|" lang("Method_for_control_Identification"),"Radio|1|IdentifyControlBy|" lang("Text_in_control") ";" lang("Classname and instance number of the control") ";" lang("Unique control ID"),"Label|" lang("Control_Identification")"|Label_Control_Identification","Radio|2|ControlTextMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Control_identifier","Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Checkbox|0|FindHiddenText|" lang("Detect hidden text"),,"Label|" lang("Exclude_text_of_a_control_in_window"),"text||ExcludeText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Hidden window"),"Checkbox|0|FindHiddenWindow|" lang("Detect hidden window"),"button|FunctionsForElementGetControlInformation||" lang("Wizard_to_get_parameters")]
	;,"Label|" lang("Insert_a_keystroke"), "Hotkey||HotkeyToInsert,"Button|customSettingButtonOfActionGet_control_textHotkeyToInsert||" lang("Insert")
	return parametersToEdit
}


GenerateNameActionGet_control_text(ID)
{
	global
	
	return % lang("Get_control_text")  "`n" GUISettingsOfElement%ID%KeysToSend "`n" lang("Control") ": " GUISettingsOfElement%ID%Control_identifier
	
}


CheckSettingsActionGet_control_text(ID)
{
	;MsgBox % "GUISettingsOfElement%ID%IdentifyControlBy " GUISettingsOfElement%ID%IdentifyControlBy
	if (GUISettingsOfElement%ID%IdentifyControlBy3 = 1)
	{
		GuiControl,,GUISettingsOfElement%ID%Label_Control_Identification,% lang("Control ID")
		
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode1
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode2
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode3		
		GuiControl,disable,GUISettingsOfElement%ID%TitleMatchMode1
		GuiControl,disable,GUISettingsOfElement%ID%TitleMatchMode2
		GuiControl,disable,GUISettingsOfElement%ID%TitleMatchMode3
		GuiControl,disable,GUISettingsOfElement%ID%Wintitle
		GuiControl,disable,GUISettingsOfElement%ID%excludeTitle
		GuiControl,disable,GUISettingsOfElement%ID%winText
		GuiControl,disable,GUISettingsOfElement%ID%FindHiddenText
		GuiControl,disable,GUISettingsOfElement%ID%ExcludeText
		GuiControl,disable,GUISettingsOfElement%ID%ahk_class
		GuiControl,disable,GUISettingsOfElement%ID%ahk_exe
		GuiControl,disable,GUISettingsOfElement%ID%ahk_id
		GuiControl,disable,GUISettingsOfElement%ID%ahk_pid
		GuiControl,disable,GUISettingsOfElement%ID%FindHiddenWindow
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode1
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode2
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode3		
		GuiControl,Enable,GUISettingsOfElement%ID%TitleMatchMode1
		GuiControl,Enable,GUISettingsOfElement%ID%TitleMatchMode2
		GuiControl,Enable,GUISettingsOfElement%ID%TitleMatchMode3
		GuiControl,Enable,GUISettingsOfElement%ID%Wintitle
		GuiControl,Enable,GUISettingsOfElement%ID%excludeTitle
		GuiControl,Enable,GUISettingsOfElement%ID%winText
		GuiControl,Enable,GUISettingsOfElement%ID%FindHiddenText
		GuiControl,Enable,GUISettingsOfElement%ID%ExcludeText
		GuiControl,Enable,GUISettingsOfElement%ID%ahk_class
		GuiControl,Enable,GUISettingsOfElement%ID%ahk_exe
		GuiControl,Enable,GUISettingsOfElement%ID%ahk_id
		GuiControl,Enable,GUISettingsOfElement%ID%ahk_pid
		GuiControl,Enable,GUISettingsOfElement%ID%FindHiddenWindow
		
	}
	
	
	if (GUISettingsOfElement%ID%IdentifyControlBy1 = 1)
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode1
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode2
		GuiControl,Enable,GUISettingsOfElement%ID%ControlTextMatchMode3
		GuiControl,,GUISettingsOfElement%ID%Label_Control_Identification,% lang("Text_in_control")
	}
	else if (GUISettingsOfElement%ID%IdentifyControlBy2 = 1)
	{
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode1
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode2
		GuiControl,disable,GUISettingsOfElement%ID%ControlTextMatchMode3
		GuiControl,,GUISettingsOfElement%ID%Label_Control_Identification,% lang("Classname and instance number of the control")
	}
	
}
