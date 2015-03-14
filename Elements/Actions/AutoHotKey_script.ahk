iniAllActions.="AutoHotKey_script|" ;Add this action to list of all actions on initialisation

runActionAutoHotKey_script(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	tempscriptpath=Generated Scripts\ActionScript_Instance_%InstanceID%_%ElementID%_%ElementIDInInstance%.ahk
	;Write all local variables in the script
	FileDelete,%tempscriptpath%
	loop,parse,%ElementID%ExportVariables,|`,`n%a_space%
	{
		if A_LoopField=
			continue
		tempv:=v_getVariable(InstanceID,v_replaceVariables(ElementID,A_LoopField))
		FileAppend,
		(
		%A_LoopField%:="%tempv%"
		
		),%tempscriptpath%
		
		
	}
	
	;~ for tempkey, TempValue in localVariables
	;~ {
		
		;~ FileAppend,
		;~ (
		;~ %tempkey%:="%TempValue%"
		
		;~ ),Generated Scripts\ActionScript%ElementID%.ahk
		
		
	;~ }
	
	;Write the script to execute in the script
	tempscript:=%ElementID%script
	FileAppend,
	(
	
	;User Script
	
	%tempscript%
	
	
	),%tempscriptpath%
	
	;Write code for importing all variables after script execution
	FileAppend,
	(
	;End
	DetectHiddenWindows, On
	
	),%tempscriptpath%
	
	;~ for tempkey, TempValue in localVariables
	;~ {
		
		;~ FileAppend,
		;~ (
		;~ ControlSetText,Edit1,localVariable|%tempkey%|`%%tempkey%`%,CommandWindowOfEditor
		
		;~ ),Generated Scripts\ActionScript%ID%.ahk
		
		
	;~ }
	
	
	loop,parse,%ElementID%ImportVariables,|`,`n%a_space%
	{
		
		FileAppend,
		(
		ControlSetText,Edit1,setVariable|Instance_%InstanceID%_%ElementID%_%ElementIDInInstance%|%A_LoopField%|`%%A_LoopField%`%,CommandWindowOfEditor
		
		),%tempscriptpath%
		
		
	}
	
	;Write code for let the flow know that the script ended
	FileAppend,
	(
	ControlSetText,Edit1,elementEnd|Instance_%InstanceID%_%ElementID%_%ElementIDInInstance%|normal,CommandWindowOfEditor
	filedelete,`%A_ScriptFullPath`%
	
	),%tempscriptpath%

	run,Generated Scripts\AutoHotkey.exe "%tempscriptpath%"
	

	
	
	return
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
	parametersToEdit:=["Label|" lang("AutoHotKey_script"),"MultiLineText||script","Label|" lang("Variables_that_should_be_exported_prior_to_execution"),"MultiLineText||ExportVariables","Label|" lang("Variables_that_should_be_imported_after_execution"),"MultiLineText||ImportVariables"]
	
	return parametersToEdit
}

GenerateNameActionAutoHotKey_script(ElementID)
{
	global
	
	return lang("AutoHotKey_script") "`n" GUISettingsOfElement%ElementID%script "`n" GUISettingsOfElement%ElementID%duration "`n"
	
}