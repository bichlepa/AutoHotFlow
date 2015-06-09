iniAllActions.="Split_a_string|" ;Add this action to list of all actions on initialisation

runActionSplit_a_string(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local OptionOmitChars
	local OptionDelimiters
	local tempVarname
	tempVarname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" 
	
	OptionOmitChars:=v_replaceVariables(InstanceID,ThreadID,%ElementID%OmitChars) 
	OptionDelimiters:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Delimiters) 
	
	loop,parse,temp,%OptionDelimiters%,%OptionOmitChars%
	{
		Result.="▬" A_LoopField
	}
	StringTrimLeft,Result,Result,1
	

	
	v_SetVariable(InstanceID,ThreadID,tempVarname,v_importVariable(Result,"list","▬"),"list")
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
	parametersToEdit:=["Label|" lang("Output list name"),"VariableName|NewList|Varname","Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello real world, Hello virtual world|VarValue","Label|" lang("Delimiter characters"),"Text|,|Delimiters","Label|" lang("Omit characters"),"Text|%a_space%%a_tab%|OmitChars"]
	
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