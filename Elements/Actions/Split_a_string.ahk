iniAllActions.="Split_a_string|" ;Add this action to list of all actions on initialisation

runActionSplit_a_string(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local OptionOmitChars
	local OptionDelimiters
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)

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
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" 
	
	if temp=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Input string is empty")
	}
	
	OptionOmitChars:=v_replaceVariables(InstanceID,ThreadID,%ElementID%OmitChars) 
	OptionDelimiters:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Delimiters) 
	
	if OptionDelimiters=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! No delimiters specified. Each character will be treated as a substring.")
	}
	
	loop,parse,temp,%OptionDelimiters%,%OptionOmitChars%
	{
		Result.="▬" A_LoopField
	}
	StringTrimLeft,Result,Result,1
	

	
	v_SetVariable(InstanceID,ThreadID,varname,v_importVariable(Result,"list","▬"),"list")
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")

	

	
	return
}
getNameActionSplit_a_string()
{
	return lang("Split_a_string")
}
getCategoryActionSplit_a_string()
{
	return lang("Variable")
}

getParametersActionSplit_a_string()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output list name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello real world, Hello virtual world", content: "StringOrExpression", contentParID: "expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Delimiter characters")})
	parametersToEdit.push({type: "Edit", id: "Delimiters", default: ",", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Omit characters")})
	parametersToEdit.push({type: "Edit", id: "OmitChars", default: "%a_space%%a_tab%", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionSplit_a_string(ID)
{
	global
	
	return % lang("Split string %1% to %2%", GUISettingsOfElement%ID%VarValue,GUISettingsOfElement%ID%Varname)
	
}

CheckSettingsActionSplit_a_string(ID)
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