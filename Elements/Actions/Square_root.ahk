iniAllActions.="Square_Root|" ;Add this action to list of all actions on initialisation

runActionSquare_Root(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	
	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Places after comma is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input value")))
		return
	}
	
	v_SetVariable(InstanceID,ThreadID,Varname,sqrt(temp))
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	

	
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Variable containing a number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 16, content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionSquare_Root(ID)
{
	global
	
	return % lang("Square_Root") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}