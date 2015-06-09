iniAllActions.="Replace_a_string|" ;Add this action to list of all actions on initialisation

runActionReplace_a_string(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempVarname
	local tempSearchText
	local tempReplaceText
	local Result
	local Options
	
	tempVarname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	
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
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
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
			v_SetVariable(InstanceID,ThreadID,tempVarname,"")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		}
		else
		{
			
			v_SetVariable(InstanceID,ThreadID,tempVarname,Result)
			v_SetVariable(InstanceID,ThreadID,"t_NumberOfReplacements",errorlevel)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
	}
	else
	{
		StringReplace,Result,temp,% tempSearchText,% tempReplaceText
		StringCaseSense,off
		if errorlevel=1 ;If no string was found
		{
			v_SetVariable(InstanceID,ThreadID,tempVarname,"")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		}
		else
		{
			
			v_SetVariable(InstanceID,ThreadID,tempVarname,Result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
	}
	
	
	StringCaseSense,off
	
	return
}
getNameActionReplace_a_string()
{
	return lang("Replace_a_string")
}
getCategoryActionReplace_a_string()
{
	return lang("Variable")
}

getParametersActionReplace_a_string()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello World|VarValue","Label| " lang("Text to search"),"Radio|1|IsExpressionSearchText|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|World|SearchText","Label| " lang("Replace by"),"Radio|1|isExpressionReplaceText|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|%a_UserName%|ReplaceText","Label|" lang("Number of replacements"),"Radio|1|ReplaceAll|" lang("Replace only the first occurence") ";" lang("Replace all occurences"),"Label|" lang("Case sensitivity"),"Radio|1|CaseSensitive|" lang("Case insensitive") ";" lang("Case sensitive")]
	
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