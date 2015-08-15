iniAllActions.="Trigonometry|" ;Add this action to list of all actions on initialisation

runActionTrigonometry(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local OutputType:=%ElementID%OutputType
	local Operation:=%ElementID%Operation
	local Result
	local Unit:=%ElementID%Unit
	
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}

	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	

	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input value is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input value")))
		return
	}
	
	
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
	
	v_SetVariable(InstanceID,ThreadID,Varname,Result)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
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
	parametersToEdit:=["Label|" lang("Output Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input number"),"Text|0.5|VarValue", "Label| " lang("Operation"),"Radio|2|Operation|" lang("Sine") ";" lang("Cosine")";" lang("Tangent")";" lang("Arcsine")";" lang("Arccosine")";" lang("Arctangent"),"Label| " lang("Unit"),"Radio|1|Unit|" lang("Radian") ";" lang("Degree")]
	
	return parametersToEdit
}

GenerateNameActionTrigonometry(ID)
{
	global
	
	return % lang("Trigonometry") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}