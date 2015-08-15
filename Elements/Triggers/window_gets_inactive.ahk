iniAllTriggers.="Window_Gets_Inactive|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerWindow_Gets_Inactive(ElementID)
{
	local tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Wintitle)
	local tempWinText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%winText)
	local tempExcludeTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%excludeTitle)
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
	;If no window specified, unlike in other actions, do not check whether the active window is active, instead error
	if (tempwinstring="" and tempWinText="" and tempExcludeTitle = "" and tempExcludeText ="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No window specified")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No window specified.") )
		return
		
	}
	
	tempwinwaitstring=%tempwinstring%,%tempWinText%,,%tempExcludeTitle%,%tempExcludeText%
	
	
	local tempDetectHiddenWindows
	local tempDetectHiddenText
	
	if %ElementID%findhiddenwindow=0
		tempDetectHiddenWindows =off
	else
		tempDetectHiddenWindows= on
	if %ElementID%findhiddentext=0
		tempDetectHiddenText= off
	else
		tempDetectHiddenText= on
	
	
	TriggerWindow_Gets_Inactive%ElementID%:=object()
	TriggerWindow_Gets_Inactive%ElementID%["Title"]:="Trigger Window_Gets_Inactive. Flow - " flowName ". ID - " ElementID
	local tempTitle:=TriggerWindow_Gets_Inactive%ElementID%["Title"]
	local generatedScript
	
	generatedScript=
	(
	%ScriptGenerationHeader%
	%ScriptGenerationCommunicationPart1%
	%ScriptGenerationEndWhenFlowClosesPart1%
	
	%ScriptGenerationIportantVars%
	
	;Main actions
	SetTitleMatchMode,%tempTitleMatchMode%
	DetectHiddenText,%tempDetectHiddenText%
	DetectHiddenWindows,%tempDetectHiddenWindows%
	WinWaitActive %tempwinwaitstring%
	loop
	{
		WinWaitNotActive,%tempwinwaitstring%
		winget,tempWinID,ID
		threadVars:=object()
		threadVars["a_windowID"]:=tempWinID
		com_SendCommand({function: "trigger",ElementID: ►ParentElementID,ThreadVariables: threadVars},"editor",►ParentFlowName)
		
		WinWaitActive %tempwinwaitstring%
		
	}
	
	
	;End of auto-execution:
	%ScriptGenerationCommunicationPart2%
		
	;Evaluating command. Add some custom messages here. Example: if (tempNewReceivedCommand["Function"]="commandname") {}
	
	%ScriptGenerationCommunicationPart3% ;Part 3 must be inserted right after part 2 and optionally some other command evaluation
	%ScriptGenerationEndWhenFlowClosesPart2%
	%ScriptGenerationFunctionSendCommand%
	%ScriptGenerationFunctionStrObj%
	)
	ScriptGenerationReplaceImportantVars(generatedScript,tempTitle,ElementID)
	
	FileDelete,Generated Scripts\%tempTitle%.ahk
	FileAppend,% generatedScript,Generated Scripts\%tempTitle%.ahk,utf-8
	local tempPID
	run,Generated Scripts\AutoHotkey.exe "Generated Scripts\%tempTitle%.ahk",,,tempPID
	;~ MsgBox % ErrorLevel
	TriggerWindow_Gets_Inactive%ElementID%["ahkpid"]:=tempPID
	
}


DisableTriggerWindow_Gets_Inactive(ElementID)
{
	global
	DetectHiddenWindows, On
	;Three different methods to terminate the trigger
	winclose,% TriggerWindow_Gets_Inactive%ElementID%["Title"] "§" CurrentManagerHiddenWindowID "§"
	com_SendCommand({function: "exit"},"custom",TriggerWindow_Gets_Inactive%ElementID%["Title"] "§" CurrentManagerHiddenWindowID "§")
	Process,close,% TriggerWindow_Gets_Inactive%ElementID%["ahkpid"]
	
}

getParametersTriggerWindow_Gets_Inactive()
{
	
	parametersToEdit:=["Label|" lang("Title_of_Window"),"Radio|1|TitleMatchMode|" lang("Start_with") ";" lang("Contain_anywhere") ";" lang("Exactly"),"text||Wintitle","Label|" lang("Exclude_title"),"text||excludeTitle","Label|" lang("Text_of_a_control_in_Window"),"text||winText","Checkbox|0|FindHiddenText|" lang("Detect hidden text"),"Label|" lang("Exclude_text_of_a_control_in_window"),"text||ExcludeText","Label|" lang("Window_Class"),"text||ahk_class","Label|" lang("Process_Name"),"text||ahk_exe","Label|" lang("Unique_window_ID"),"text||ahk_id","Label|" lang("Unique_Process_ID"),"text||ahk_pid","Label|" lang("Hidden window"),"Checkbox|0|FindHiddenWindow|" lang("Detect hidden window"),"Label|" lang("Get_parameters"), "button|FunctionsForElementGetWindowInformation||" lang("Get_Parameters")]
	
	
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


GenerateNameTriggerWindow_Gets_Inactive(ID)
{
	tempNameString:=lang("Window_Gets_Inactive") " - "
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
