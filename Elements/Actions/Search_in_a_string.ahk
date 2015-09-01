iniAllActions.="Search_in_a_string|" ;Add this action to list of all actions on initialisation

runActionSearch_in_a_string(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempSearchText
	local OccurenceNumber
	local Offset
	local Result
	local Options
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	
	if temp=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Input string is empty")
	}
	
	if %ElementID%IsExpressionSearchText=1
		tempSearchText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%SearchText)
	else
		tempSearchText:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%SearchText)
	
	if tempSearchText=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Search text is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Search text")))
		return
	}
	
	
	OccurenceNumber:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%OccurenceNumber)
	if OccurenceNumber is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Occurence number is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Occurence number")))
		return
	}
	
	Offset:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Offset)
	if Offset is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Offset is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Offset")))
		return
	}
	
	if %ElementID%CaseSensitive=2
	{
		StringCaseSense,on
	}
	
	
	if %ElementID%LeftOrRight=1 ;Left
	{
		Options=L%OccurenceNumber%
	}
	else ;Right
	{
		Options=R%OccurenceNumber%
	}
		
	StringGetPos,Result,temp,% tempSearchText,%Options%,%Offset% ;later: Result + 1: because the first character intex is 0 in this function
	StringCaseSense,off
	
	if errorlevel=1 ;If no string was found
	{
		v_SetVariable(InstanceID,ThreadID,Varname,"") 
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Searched text not found.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Searched text not found"))
	}
	else
	{
		v_SetVariable(InstanceID,ThreadID,Varname,Result+1)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	
	
	
	
	
	return
}
getNameActionSearch_in_a_string()
{
	return lang("Search_in_a_string")
}
getCategoryActionSearch_in_a_string()
{
	return lang("Variable")
}

getParametersActionSearch_in_a_string()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewPosition", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Text to search")})
	parametersToEdit.push({type: "Radio", id: "IsExpressionSearchText", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "SearchText", default: "World", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Which occurence")})
	parametersToEdit.push({type: "Edit", id: "OccurenceNumber", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "LeftOrRight", default: 1, choices: [lang("From left"), lang("From right")]})
	parametersToEdit.push({type: "Label", label: lang("Start position")})
	parametersToEdit.push({type: "Edit", id: "Offset", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Case sensitivity")})
	parametersToEdit.push({type: "Radio", id: "CaseSensitive", default: 1, choices: [lang("Case insensitive"), lang("Case sensitive")]})

	return parametersToEdit
}

GenerateNameActionSearch_in_a_string(ID)
{
	global
	
	return % lang("Search_in_a_string") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

CheckSettingsActionSearch_in_a_string(ID)
{
	static previousLeftSide=0
	static previousRightSide=0
	
	
}