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
	if %ElementID%IsExpressionSearchText=1
		tempSearchText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%SearchText)
	else
		tempSearchText:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%SearchText)
	
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
	
	parametersToEdit:=["Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello World|VarValue","Label| " lang("Text to search"),"Radio|1|IsExpressionSearchText|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|World|SearchText","Label|" lang("Search text position"),"Radio|3|WhereToBegin|" lang("Starts with") ";" lang("Ends with") ";" lang("Contains anywhere"),"Label|" lang("Case sensitivity"),"Radio|1|CaseSensitive|" lang("Case insensitive") ";" lang("Case sensitive")]
	
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