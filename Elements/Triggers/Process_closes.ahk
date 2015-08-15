iniAllTriggers.="Process_closes|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerProcess_closes(ElementID)
{
	global
	
	local tempProcessName:=v_replaceVariables(0,0,%ElementID%ProcessName)
	
	if tempProcessName=
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! Process name is not specified.")
		MsgBox,16,% lang("Error"),% lang("Trigger '%1%' couln't be activated!", %ElementID%name) " " lang("%1% is not specified.",lang("Process name"))
		
		return
	}
	
	TriggerProcess_closes%ElementID%:=object()
	TriggerProcess_closes%ElementID%["Title"]:="Trigger Process_closes. Flow - " flowName ". ID - " ElementID
	local tempTitle:=TriggerProcess_closes%ElementID%["Title"]
	local generatedScript
	
	generatedScript=
	(
	%ScriptGenerationHeader%
	%ScriptGenerationCommunicationPart1%
	%ScriptGenerationEndWhenFlowClosesPart1%
	
	%ScriptGenerationIportantVars%
	
	;Main actions
	loop
	{
		process,wait,%tempProcessName%
		
		process,waitclose,%tempProcessName%
		
		threadVars:=object()
		
		com_SendCommand({function: "trigger",ElementID: ►ParentElementID,ThreadVariables: threadVars},"editor",►ParentFlowName)
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
	TriggerProcess_closes%ElementID%["ahkpid"]:=tempPID
}

DisableTriggerProcess_closes(ElementID)
{
	global
	DetectHiddenWindows, On
	;Three different methods to terminate the trigger
	winclose,% TriggerProcess_closes%ElementID%["Title"] "§" CurrentManagerHiddenWindowID "§"
	com_SendCommand({function: "exit"},"custom",TriggerProcess_closes%ElementID%["Title"] "§" CurrentManagerHiddenWindowID "§")
	Process,close,% TriggerProcess_closes%ElementID%["ahkpid"]
}

getParametersTriggerProcess_closes()
{
	
	parametersToEdit:=["Label|" lang("Process name or ID"),"text||ProcessName"]
	
	
	return parametersToEdit
}

getNameTriggerProcess_closes()
{
	return lang("Process_closes")
}
getCategoryTriggerProcess_closes()
{
	return lang("Process")
}





GenerateNameTriggerProcess_closes(ID)
{
	
	
	return lang("Process_closes") " - " GUISettingsOfElement%ID%ProcessName
	
}

