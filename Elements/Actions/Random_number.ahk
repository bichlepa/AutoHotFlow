iniAllActions.="Random_number|" ;Add this action to list of all actions on initialisation

runActionRandom_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempmin
	local tempmax
	local result
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	
	tempmin:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%MinValue)
	tempmax:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%MaxValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if tempmin is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Minimum value is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Minimum value")))
		return
	}
	if tempmax is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Maximum value is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Maximum value")))
		return
		
	}
	
	;~ if tempmax<tempmin ;Ignore is, since ahk ignores it, too
	;~ {
		;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Minimum value is greater than maximum value.")
		;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Minimum value is greater than maximum value"))
		;~ return
		
	;~ }
	
	Random,result,tempmin,tempmax
	v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),result)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionRandom_number()
{
	return lang("Random_number")
}
getCategoryActionRandom_number()
{
	return lang("Variable")
}

getParametersActionRandom_number()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Minimum value"),"Text|0|MinValue","Label| " lang("Maximum value"),"Text|100|MaxValue"]
	
	return parametersToEdit
}

GenerateNameActionRandom_number(ID)
{
	global
	
	return % lang("Random_number") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}