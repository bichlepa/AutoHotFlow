iniAllActions.="Trigonometry|" ;Add this action to list of all actions on initialisation

runActionTrigonometry(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local OutputType
	local Operation
	local Result
	local Unit
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	
	OutputType:=%ElementID%OutputType
	Operation:=%ElementID%Operation
	Unit:=%ElementID%Unit

	if temp is number
	{
		if (Operation<=3 and Operation>=1) ;If input is radian or degree
		{
			if Unit=2 ;If degree, convert to radian
			{
				temp/=180/3.141592653589793
			}
		}
		if Operation=1 ;Sine
			Result:=Sin(temp)
		else if Operation=2 ;Cosine
			Result:=Cos(temp)
		else if Operation=3 ;Tangent
			Result:=Tan(temp)
		else if Operation=4 ;ASine
			Result:=ASin(temp)
		else if Operation=5 ;ACosine
			Result:=ACos(temp)
		else if Operation=6 ;ATangent
			Result:=ATan(temp)
		if (Operation<=6 and Operation>=3) ;If output is radian or degree
		{
			if Unit=2 ;If degree, convert to radian
			{
				Result*=180/3.141592653589793
			}
		}
		
		v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),Result)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	
	return
}
getNameActionTrigonometry()
{
	return lang("Trigonometry")
}
getCategoryActionTrigonometry()
{
	return lang("Variable")
}

getParametersActionTrigonometry()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Number"),"Radio|2|expression|" lang("This is a number") ";" lang("This is a variable name or expression") ,"Text|0.5|VarValue", "Label| " lang("Operation"),"Radio|2|Operation|" lang("Sine") ";" lang("Cosine")";" lang("Tangent")";" lang("Arcsine")";" lang("Arccosine")";" lang("Arctangent"),"Label| " lang("Unit"),"Radio|1|Unit|" lang("Radian") ";" lang("Degree")]
	
	return parametersToEdit
}

GenerateNameActionTrigonometry(ID)
{
	global
	
	return % lang("Trigonometry") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}