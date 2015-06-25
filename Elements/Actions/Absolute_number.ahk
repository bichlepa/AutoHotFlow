iniAllActions.="Absolute_number|" ;Add this action to list of all actions on initialisation

runActionAbsolute_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	
	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if temp is number
	{
		
		v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),abs(temp))
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
	{
		logger("f0",lang("Instance") " " InstanceID " - " lang(%ElementID%type) " '" %ElementID%name "': " lang("Error") "! " lang("Input number %1% is not a number",temp))
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	}

	
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
	
	return % lang("Absolute_number") " - " GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

showHelpForActionAbsolute_number()
{
	
	;~ ui_MakeNewHelp()
	
	;~ ui_AddToHelp()
	
	;~ ui_showHelp()
	
}