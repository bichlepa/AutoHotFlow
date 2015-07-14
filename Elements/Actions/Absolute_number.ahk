iniAllActions.="Absolute_number|" ;Add this action to list of all actions on initialisation

runActionAbsolute_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output variable name '%1%'",varname)) )
		return
	}
	
	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input number " temp " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input number '%1%'",temp)) )
		return
	}
	
	v_SetVariable(InstanceID,ThreadID,varname,abs(temp))
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")

	
	return
}
getNameActionAbsolute_number()
{
	return lang("Absolute_number")
}
getCategoryActionAbsolute_number()
{
	return lang("Variable")
}

getParametersActionAbsolute_number()
{
	global
	parametersToEdit:=["Label|" lang("Output_Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input number"),"Text|-2|VarValue"]
	
	return parametersToEdit
}

GenerateNameActionAbsolute_number(ID)
{
	global
	
	return % lang("Absolute_number") ": " GUISettingsOfElement%ID%Varname " = |" GUISettingsOfElement%ID%VarValue "|"
	
}

showHelpForActionAbsolute_number()
{
	
	;~ ui_MakeNewHelp()
	
	;~ ui_AddToHelp()
	
	;~ ui_showHelp()
	
}