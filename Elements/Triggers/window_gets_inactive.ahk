iniAllTriggers.="Window_Gets_Inactive|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerWindow_Gets_Inactive(ID)
{
	global
	
	tempWinTitle:=v_replaceVariables(0,%ID%Wintitle)
	tempWinText:=v_replaceVariables(0,%ID%winText)
	tempExcludeTitle:=v_replaceVariables(0,%ID%excludeTitle)
	tempExcludeText:=v_replaceVariables(0,%ID%ExcludeText)
	tempTitleMatchMode :=%ID%TitleMatchMode
	tempahk_class:=v_replaceVariables(0,%ID%ahk_class)
	tempahk_exe:=v_replaceVariables(0,%ID%ahk_exe)
	tempahk_id:=v_replaceVariables(0,%ID%ahk_id)
	tempahk_pid:=v_replaceVariables(0,%ID%ahk_pid)
	
	
	tempwinwaitstring=%tempWinTitle%
	if tempahk_class<>
		tempwinwaitstring=%tempwinwaitstring% ahk_class %tempahk_class%
	if tempahk_id<>
		tempwinwaitstring=%tempwinwaitstring% ahk_id %tempahk_id%
	if tempahk_pid<>
		tempwinwaitstring=%tempwinwaitstring% ahk_pid %tempahk_pid%
	if tempahk_exe<>
		tempwinwaitstring=%tempwinwaitstring% ahk_exe %tempahk_exe%
	
	tempwinwaitstring=%tempwinwaitstring%,%tempWinText%,,%tempExcludeTitle%,%tempExcludeText%
	
	FileDelete,Generated Scripts\TriggerWindow_Gets_Inactive%ID%.ahk
	FileAppend,
	(
	#SingleInstance force
	DetectHiddenWindows, On
	SetTitleMatchMode,%tempTitleMatchMode%
	
	;open a window so the main program can stop it
	gui,45:default
	gui,new,,CommandWindowFor%ID%
	gui,add,edit,vcommandFortrigger gCommandForTrigger
	
	loop
	{
		WinWaitNotActive,%tempwinwaitstring%
		
		
		ControlSetText,Edit1,Run,CommandWindowOfEditor,Ѻ%flowname%Ѻ
		WinWaitActive %tempwinwaitstring%
	}
	
	CommandForTrigger:
	gui,submit
	if CommandForTrigger=exit
	{
		exitapp
	}
	),Generated Scripts\TriggerWindow_Gets_Inactive%ID%.ahk
	run,Generated Scripts\AutoHotkey.exe "Generated Scripts\TriggerWindow_Gets_Inactive%ID%.ahk"
	
}

getParametersTriggerWindow_Gets_Inactive()
{
	
	parametersToEdit:=["Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Label|" lang("Exclude_text_of_a_control_in_window"),"text||ExcludeText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Get_parameters"), "button|FunctionsForElementGetWindowInformation||" lang("Get_Parameters")]
	
	
	return parametersToEdit
}

getNameTriggerWindow_Gets_Inactive()
{
	return lang("Window_Gets_Inactive")
}
getCategoryTriggerWindow_Gets_Inactive()
{
	return lang("Window")
}


DisableTriggerWindow_Gets_Inactive(ID)
{
	DetectHiddenWindows, On
	ControlSetText,Edit1,exit,CommandWindowFor%ID%
	
}

GenerateNameTriggerWindow_Gets_Inactive(ID)
{
	tempNameString:=lang("Window_Gets_Inactive")
	if GUISettingsOfElement%ID%Wintitle<>
	{
		
		if GUISettingsOfElement%ID%TitleMatchMode=1
			tempNameString:=tempNameString "`n" lang("Title begins with") ": " GUISettingsOfElement%ID%Wintitle
		else if GUISettingsOfElement%ID%TitleMatchMode=2
			tempNameString:=tempNameString "`n" lang("Title includes") ": " GUISettingsOfElement%ID%Wintitle
		else if if GUISettingsOfElement%ID%TitleMatchMode=3
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
goto,jumpOverTriggerWindow_Gets_InactiveGetParameters


TriggerWindow_Gets_InactiveGetParameters:

goto,FunctionsForElementGetWindowInformation




jumpOverTriggerWindow_Gets_InactiveGetParameters:
temp:=temp
