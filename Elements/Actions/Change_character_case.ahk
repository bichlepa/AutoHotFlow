iniAllActions.="Change_character_case|" ;Add this action to list of all actions on initialisation

runActionChange_character_case(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local OptionCharCase
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)

	
	if varname=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name is empty.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Output variable name")))
		return
	}
	if temp=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input string is empty.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Input string")))
	}
	
	
	OptionCharCase:=v_replaceVariables(InstanceID,ThreadID,%ElementID%CharCase) 
	if OptionCharCase=1 ;Uppercase
		StringUpper,Result,temp
	else if OptionCharCase=2 ;Lowercase
		StringLower,Result,temp
	else if OptionCharCase=3
		StringUpper,Result,temp,T ;First character of a word is uppercase
	v_SetVariable(InstanceID,ThreadID,Varname,Result)
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
	local tempcase
	
	if GUISettingsOfElement%ID%CharCase1
		tempcase:=lang("Uppercase")
	else if GUISettingsOfElement%ID%CharCase2
		tempcase:=lang("Lowercase")
	else if GUISettingsOfElement%ID%CharCase3
		tempcase:=lang("Firt character of a word is uppercase")
	
	return % lang("Change_character_case") ": " GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue " to " tempcase
	
}

