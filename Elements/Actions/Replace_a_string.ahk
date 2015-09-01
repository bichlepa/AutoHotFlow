iniAllActions.="Replace_a_string|" ;Add this action to list of all actions on initialisation

runActionReplace_a_string(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempSearchText
	local tempReplaceText
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
	
	if %ElementID%IsExpressionSearchText=1
		tempSearchText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%SearchText)
	else
		tempSearchText:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%SearchText)
	
	if %ElementID%isExpressionReplaceText=1
		tempReplaceText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ReplaceText)
	else
		tempReplaceText:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%ReplaceText)
	
	if tempSearchText=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Search text is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Search text")))
		return
	}
	
	if %ElementID%CaseSensitive=2
	{
		StringCaseSense,on
	}
	
	
	if %ElementID%ReplaceAll=2
	{
		StringReplace,Result,temp,% tempSearchText,% tempReplaceText,UseErrorLevel
		StringCaseSense,off
		if errorlevel=0 ;If no string was found
		{
			v_SetVariable(InstanceID,ThreadID,varname,"")
			v_SetVariable(InstanceID,ThreadID,"a_Replacements",0,,true)
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Searched text not found.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Searched text not found"))
			return
		}
		
		
		v_SetVariable(InstanceID,ThreadID,varname,Result)
		v_SetVariable(InstanceID,ThreadID,"a_Replacements",errorlevel,,true)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	else
	{
		StringReplace,Result,temp,% tempSearchText,% tempReplaceText
		StringCaseSense,off
		if errorlevel=1 ;If no string was found
		{
			v_SetVariable(InstanceID,ThreadID,varname,"")
			v_SetVariable(InstanceID,ThreadID,"a_Replacements",0,,true)
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Searched text not found.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Searched text not found"))
			return
		}
		
		v_SetVariable(InstanceID,ThreadID,varname,Result)
		v_SetVariable(InstanceID,ThreadID,"a_Replacements",1,,true)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	
	
	StringCaseSense,off
	
	return
}
getNameActionReplace_a_string()
{
	return lang("Replace_in_a_string")
}
getCategoryActionReplace_a_string()
{
	return lang("Variable")
}

getParametersActionReplace_a_string()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Text to search")})
	parametersToEdit.push({type: "Radio", id: "IsExpressionSearchText", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "SearchText", default: "World", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Replace by")})
	parametersToEdit.push({type: "Radio", id: "isExpressionReplaceText", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "ReplaceText", default: "%a_UserName%", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Number of replacements")})
	parametersToEdit.push({type: "Radio", id: "ReplaceAll", default: 1, choices: [lang("Replace only the first occurence"), lang("Replace all occurences")]})
	parametersToEdit.push({type: "Label", label: lang("Case sensitivity")})
	parametersToEdit.push({type: "Radio", id: "CaseSensitive", default: 1, choices: [lang("Case insensitive"), lang("Case sensitive")]})

	return parametersToEdit
}

GenerateNameActionReplace_a_string(ID)
{
	global
	
	return % lang("Replace_a_string") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

CheckSettingsActionReplace_a_string(ID)
{
	static previousLeftSide=0
	static previousRightSide=0
	
	if GUISettingsOfElement%ID%TrimWhat1=1 ;Trim a count of characters
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Length
		GuiControl,Disable,GUISettingsOfElement%ID%SpacesAndTabs
		GuiControl,Disable,GUISettingsOfElement%ID%OmitChars
		
	}
	else ;Trim specific characters
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Length
		GuiControl,Enable,GUISettingsOfElement%ID%SpacesAndTabs

		if GUISettingsOfElement%ID%SpacesAndTabs=1
		{
			GuiControl,Disable,GUISettingsOfElement%ID%OmitChars
		}
		else
			GuiControl,Enable,GUISettingsOfElement%ID%OmitChars
	}
	
	
	if (GUISettingsOfElement%ID%LeftSide=0 and GUISettingsOfElement%ID%RightSide=0)
	{
		if previousRightSide=1
		{
			GuiControl,,GUISettingsOfElement%ID%LeftSide,1
			previousLeftSide=1
			previousRightSide=0
		}
		else
		{
			GuiControl,,GUISettingsOfElement%ID%RightSide,1
			previousRightSide=1
			previousLeftSide=0
		}
	}
	else
	{
		previousLeftSide:=GUISettingsOfElement%ID%LeftSide
		previousRightSide:=GUISettingsOfElement%ID%RightSide
	}
}