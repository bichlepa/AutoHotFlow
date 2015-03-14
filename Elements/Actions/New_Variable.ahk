iniAllActions.="New_variable|" ;Add this action to list of all actions on initialisation

runActionNew_variable(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if %ElementID%expression=1
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),v_replaceVariables(InstanceID,%ElementID%VarValue))
	else
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),v_EvaluateExpression(InstanceID,%ElementID%VarValue))
	

	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionNew_variable()
{
	return lang("New_variable")
}
getCategoryActionNew_variable()
{
	return lang("Variable")
}

getParametersActionNew_variable()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Value"),"Radio|1|expression|" lang("This is a value") ";" lang("This is a variable name or expression"),"Text||VarValue"]
	
	return parametersToEdit
}

GenerateNameActionNew_variable(ID)
{
	global
	
	return % lang("New_variable") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}