iniAllConditions.="String_contains_text|" ;Add this condition to list of all conditions on initialisation

runConditionString_contains_text(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempVarValue
	local tempSearchText
	
	if %ElementID%expression=1
		tempVarValue:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		tempVarValue:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	
	if tempVarValue=
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
	
	;~ MsgBox %tempVarValue% - %tempSearchText% 
	
	if %ElementID%WhereToBegin=3 ;Search somewhere
	{
		if %ElementID%CaseSensitive=2
		{
			StringCaseSense,on
		}
		IfInString, tempVarValue,%tempSearchText%
		{
			StringCaseSense,off
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		}
		else
		{
			StringCaseSense,off
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
	}
	else if %ElementID%WhereToBegin=1 ;Starts with
	{
		StringLeft,temp,tempVarValue,strlen(tempSearchText)
		if %ElementID%CaseSensitive=1 ;Case insensitive
		{
			if (temp=tempSearchText)
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
			else
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
		else
		{
			if (temp==tempSearchText)
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
			else
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
	}
	else if %ElementID%WhereToBegin=2 ;Ends with
	{
		StringRight,temp,tempVarValue,strlen(tempSearchText)
		
		if %ElementID%CaseSensitive=1 ;Case insensitive
		{
			if (temp=tempSearchText)
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
			else
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
		else
		{
			if (temp==tempSearchText)
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
			else
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
	}
	
	
	StringCaseSense,off
}





getParametersConditionString_contains_text()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: "StringOrExpression", contentParID: "expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Text to search")})
	parametersToEdit.push({type: "Radio", id: "IsExpressionSearchText", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "SearchText", default: "World", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Search text position")})
	parametersToEdit.push({type: "Radio", id: "WhereToBegin", default: 3, choices: [lang("Starts with"), lang("Ends with"), lang("Contains anywhere")]})
	parametersToEdit.push({type: "Label", label: lang("Case sensitivity")})
	parametersToEdit.push({type: "Radio", id: "CaseSensitive", default: 1, choices: [lang("Case insensitive"), lang("Case sensitive")]})

	return parametersToEdit
}

getNameConditionString_contains_text()
{
	return lang("String_contains_text")
}
getCategoryConditionString_contains_text()
{
	return lang("Variable")
}

GenerateNameConditionString_contains_text(ID)
{
	return lang("String_contains_text") ": " GUISettingsOfElement%ID%VarValue " - " GUISettingsOfElement%ID%SearchText
	
}