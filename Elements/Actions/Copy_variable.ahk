iniAllActions.="Copy_variable|" ;Add this action to list of all actions on initialisation

runActionCopy_variable(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	local Varname:=v_replaceVariables(InstanceID,%ElementID%Varname)
	local OldVarname:=v_replaceVariables(InstanceID,%ElementID%OldVarname)
	local tempType:=v_getVariableType(InstanceID,%ElementID%OldVarname)
	local tempValue:=v_getVariable(InstanceID,%ElementID%OldVarname,tempType)
	v_setVariable(InstanceID,%ElementID%Varname,tempValue,tempType)

	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
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