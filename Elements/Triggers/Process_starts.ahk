iniAllTriggers.="Process_starts|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerProcess_starts(ElementID)
{
	global
	
	local tempProcessName:=v_replaceVariables(0,0,%ElementID%ProcessName)
	
	if tempProcessName=
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! Process name is not specified.")
		MsgBox,16,% lang("Error"),% lang("Trigger '%1%' couln't be activated!", %ElementID%name) " " lang("%1% is not specified.",lang("Process name"))
		
		return
	}
	
	TriggerProcess_starts%ElementID%:=object()
	TriggerProcess_starts%ElementID%["Title"]:="Trigger Process Starts. Flow - " flowSettings.Name ". ID - " ElementID
	local tempTitle:=TriggerProcess_starts%ElementID%["Title"]
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
		
		threadVars:=object()
		threadVars["a_pid"]:=errorlevel
		com_SendCommand({function: "trigger",ElementID: ►ParentElementID,ThreadVariables: threadVars},"editor",►ParentFlowName)
		
		process,waitclose,%tempProcessName%
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
	TriggerProcess_starts%ElementID%["ahkpid"]:=tempPID
	
	
}

DisableTriggerProcess_starts(ElementID)
{
	global
	DetectHiddenWindows, On
	;Three different methods to terminate the trigger
	winclose,% TriggerProcess_starts%ElementID%["Title"] "§" CurrentManagerHiddenWindowID "§"
	com_SendCommand({function: "exit"},"custom",TriggerProcess_starts%ElementID%["Title"] "§" CurrentManagerHiddenWindowID "§")
	Process,close,% TriggerProcess_starts%ElementID%["ahkpid"]
	

}

getParametersTriggerProcess_starts()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Process name")})
	parametersToEdit.push({type: "Edit", id: "ProcessName", content: "String", WarnIfEmpty: true})

	
	return parametersToEdit
}

getNameTriggerProcess_starts()
{
	return lang("Process_starts")
}
getCategoryTriggerProcess_starts()
{
	return lang("Process")
}


GenerateNameTriggerProcess_starts(ID)
{
	return lang("Process_starts") " - " GUISettingsOfElement%ID%ProcessName
	
}

