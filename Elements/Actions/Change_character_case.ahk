iniAllActions.="Change_character_case|" ;Add this action to list of all actions on initialisation

runActionChange_character_case(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local OptionCharCase
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)


	OptionCharCase:=v_replaceVariables(InstanceID,ThreadID,%ElementID%CharCase) 
	if OptionCharCase=1 ;Uppercase
		StringUpper,Result,temp
	else if OptionCharCase=2 ;Lowercase
		StringLower,Result,temp
	else if OptionCharCase=3
		StringUpper,Result,temp,T ;First character of a word is uppercase
	v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),Result)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")

	return
}
getNameActionChange_character_case()
{
	return lang("Change_character_case")
}
getCategoryActionChange_character_case()
{
	return lang("Variable")
}

getParametersActionChange_character_case()
{
	global
	parametersToEdit:=["Label|" lang("Output Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello World|VarValue","Label|" lang("Which case (character case)"),"Radio|1|CharCase|" lang("Uppercase") ";" lang("Lowercase") ";" lang("Firt character of a word is uppercase")]
	
	return parametersToEdit
}

GenerateNameActionChange_character_case(ID)
{
	global
	
	return % lang("Change_character_case") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

