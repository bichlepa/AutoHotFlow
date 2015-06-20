iniAllActions.="Square_Root|" ;Add this action to list of all actions on initialisation

runActionSquare_Root(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	
	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if temp is number
	{
		v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),sqrt(temp))
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	
	return
}
getNameActionSquare_Root()
{
	return lang("Square_Root")
}
getCategoryActionSquare_Root()
{
	return lang("Variable")
}

getParametersActionSquare_Root()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Variable containing a number") ,"Text|16|VarValue"]
	
	return parametersToEdit
}

GenerateNameActionSquare_Root(ID)
{
	global
	
	return % lang("Square_Root") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}