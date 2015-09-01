iniAllActions.="AutoHotKey_script|" ;Add this action to list of all actions on initialisation
ActionAutoHotKey_scriptAllScripts:=Object()


runActionAutoHotKey_script(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local exportVars:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ExportVariables)
	local importVars:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ImportVariables)
	local script:=%ElementID%script
	
	
	
	ActionAutoHotKey_script%ElementID%:=object()
	ActionAutoHotKey_script%ElementID%["Title"]:="Action AutoHotKey_script. Flow - " flowName ". ID - " ElementID
	ActionAutoHotKey_script%ElementID%["InstanceID"]:=InstanceID
	ActionAutoHotKey_script%ElementID%["ThreadID"]:=ThreadID
	ActionAutoHotKey_script%ElementID%["ElementID"]:=ElementID
	ActionAutoHotKey_script%ElementID%["ElementIDInInstance"]:=ElementIDInInstance
	
	local tempTitle:=ActionAutoHotKey_script%ElementID%["Title"]
	local generatedScriptPartImportVars
	local generatedScriptPartImportVars
	local generatedScript
	local tempvalue
	
	;Write all local variables in the script
	loop,parse,exportVars,|`,`n%a_space%
	{
		if A_LoopField=
			continue
		tempvalue:=v_getVariable(InstanceID,ThreadID,A_LoopField,"AsIs")
		if isobject(tempvalue)
		{
			tempvalue:=strobj(tempvalue)
			generatedScriptPartImportVars.=A_LoopField "=`n(`n" tempvalue "`n)`n"
		}
		else
			generatedScriptPartImportVars.=A_LoopField "=" tempvalue "`n"
		
		
		
	}
	
	;Get all local variables from the script
	loop,parse,importVars,|`,`n%a_space%
	{
		if A_LoopField=
			continue
		
		generatedScriptPartImportVars.="►localVars[""" A_LoopField """]:=" A_LoopField "`n"
		
		
	}
	
	
	generatedScript=
	(
	%ScriptGenerationHeader%
	%ScriptGenerationCommunicationPart1%
	%ScriptGenerationEndWhenFlowClosesPart1%
	
	%ScriptGenerationIportantVars%
	
	►Result=
	►localVars:=object()
	
	%generatedScriptPartImportVars%
	
	%script%
	
	endExecution:
	
	
	if result=exception
		►Result=exception
	else
		►Result=normal
	
	%generatedScriptPartImportVars%
	
	com_SendCommand({function: "GeneratedScriptHasFinished",result: ►Result,ElementID: ►ParentElementID,ThreadID: ►ParentThreadID,InstanceID: ►ParentInstanceID,ElementIDInInstance: ►ParentElementIDInInstance,LocalVariables: ►localVars},"editor",►ParentFlowName)
	
	;End of auto-execution:
	%ScriptGenerationCommunicationPart2%
		
	;Evaluating command. Add some custom messages here. Example: if (tempNewReceivedCommand["Function"]="commandname") {}
	
	%ScriptGenerationCommunicationPart3% ;Part 3 must be inserted right after part 2 and optionally some other command evaluation
	%ScriptGenerationEndWhenFlowClosesPart2%
	%ScriptGenerationFunctionSendCommand%
	%ScriptGenerationFunctionStrObj%
	)
	ScriptGenerationReplaceImportantVars(generatedScript,tempTitle,ElementID,InstanceID,ThreadID,ElementIDInInstance)
	
	
	FileDelete,Generated Scripts\%tempTitle%.ahk
	FileAppend,% generatedScript,Generated Scripts\%tempTitle%.ahk,utf-8
	local tempPID
	run,Generated Scripts\AutoHotkey.exe "Generated Scripts\%tempTitle%.ahk",,,tempPID
	;~ MsgBox % ErrorLevel
	ActionAutoHotKey_script%ElementID%["ahkpid"]:=tempPID
	
	ActionAutoHotKey_scriptAllScripts.push(ActionAutoHotKey_script%ElementID%)
	return
}

stopOneElementActionAutoHotKey_script(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local copyObject:=ActionAutoHotKey_scriptAllScripts.clone()
	
	for index, ActionAutoHotKey_scriptOneScript in copyObject
	{
		if (ActionAutoHotKey_scriptOneScript["InstanceID"]=InstanceID and ActionAutoHotKey_scriptOneScript["ThreadID"]=ThreadID and ActionAutoHotKey_scriptOneScript["ElementID"]=ElementID and ActionAutoHotKey_scriptOneScript["ElementIDInInstance"]=ElementIDInInstance)
		{
			ActionAutoHotKey_scriptAllScripts.delete(index)
			break
			
		}
	}
}

stopActionAutoHotKey_script(ElementID)
{
	global

	DetectHiddenWindows, On
	
	for index, ActionAutoHotKey_scriptOneScript in ActionAutoHotKey_scriptAllScripts
	{
		;Three different methods to terminate the external script
		winclose,% ActionAutoHotKey_scriptOneScript["Title"] "§" CurrentManagerHiddenWindowID "§"
		com_SendCommand({function: "exit"},"custom",ActionAutoHotKey_scriptOneScript["Title"] "§" CurrentManagerHiddenWindowID "§")
		Process,close,% ActionAutoHotKey_scriptOneScript["ahkpid"]
	}
	
	ActionAutoHotKey_scriptOneScript:=Object() ;Delete all elements from the list of all GUIs
	
}


getNameActionAutoHotKey_script()
{
	return lang("AutoHotKey_script")
}
getCategoryActionAutoHotKey_script()
{
	return lang("For_experts")
}

getParametersActionAutoHotKey_script()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("AutoHotKey_script"), WarnIfEmpty: true})
	parametersToEdit.push({type: "edit", id: "script", multiline: 1})
	parametersToEdit.push({type: "Label", label: lang("Variables_that_should_be_exported_prior_to_execution")})
	parametersToEdit.push({type: "edit", id: "ExportVariables", multiline: 1})
	parametersToEdit.push({type: "Label", label: lang("Variables_that_should_be_imported_after_execution")})
	parametersToEdit.push({type: "edit", id: "ImportVariables", multiline: 1})


	return parametersToEdit
}

GenerateNameActionAutoHotKey_script(ElementID)
{
	global
	
	return lang("AutoHotKey_script") "`n" GUISettingsOfElement%ElementID%script "`n" GUISettingsOfElement%ElementID%duration "`n"
	
}