iniAllActions.="Copy_variable|" ;Add this action to list of all actions on initialisation

runActionCopy_variable(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local OldVarname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%OldVarname)
	local tempType:=v_getVariableType(InstanceID,ThreadID,%ElementID%OldVarname)
	local tempValue:=v_getVariable(InstanceID,ThreadID,%ElementID%OldVarname,tempType)
	v_setVariable(InstanceID,ThreadID,%ElementID%Varname,tempValue,tempType)

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionCopy_variable()
{
	return lang("Copy_variable")
}
getCategoryActionCopy_variable()
{
	return lang("Variable")
}

getParametersActionCopy_variable()
{
	global
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|NewVariable|Varname","Label| " lang("Input variable name"),"VariableName|Variable|OldVarname"]
	
	return parametersToEdit
}

GenerateNameActionCopy_variable(ID)
{
	global
	
	return % lang("Copy_variable") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%OldVarname
	
}