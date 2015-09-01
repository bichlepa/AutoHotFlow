iniAllActions.="Get_Clipboard|" ;Add this action to list of all actions on initialisation

runActionGet_Clipboard(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output variable name '%1%'",varname)) )
		return
	}
	
	;~ if %ElementID%All=0 ;Binary data not supported
	;~ {
		;~ tempClipboardAll:=ClipboardAll
		;~ v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),tempClipboardAll,binary)
	;~ }
	;~ else
	;~ {
		v_SetVariable(InstanceID,ThreadID,varname,Clipboard)
	;~ }
	
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionGet_Clipboard()
{
	return lang("Get Clipboard")
}
getCategoryActionGet_Clipboard()
{
	return lang("Variable")
}

getParametersActionGet_Clipboard()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "Clipboard", content: "VariableName", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionGet_Clipboard(ID)
{
	global
	
	return % lang("Get_Clipboard") "`n" lang("to %1%",GUISettingsOfElement%ID%Varname) 
	
}