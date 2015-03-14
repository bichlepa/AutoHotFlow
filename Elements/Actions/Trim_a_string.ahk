iniAllActions.="Trim_a_string|" ;Add this action to list of all actions on initialisation

runActionTrim_a_string(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local OptionOmitChars

	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if %ElementID%TrimWhat=1 ;Trim a number of characters
	{
		if %ElementID%LeftSide=1
			StringTrimLeft,temp,temp,%ElementID%Length
		if %ElementID%RightSide=1
			StringTrimRight,temp,temp,%ElementID%Length
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),temp)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	else  ;Trim specific characters
	{
		if %ElementID%SpacesAndTabs=1
			OptionOmitChars:=" `t"
		else
			OptionOmitChars:=v_replaceVariables(InstanceID,%ElementID%OmitChars) 
		if (%ElementID%LeftSide=1 and %ElementID%RightSide=1)
			Result:=Trim(temp,OptionOmitChars)
		else if (%ElementID%LeftSide=1 and %ElementID%RightSide=0)
			Result:=LTrim(temp,OptionOmitChars)
		else if (%ElementID%LeftSide=0 and %ElementID%RightSide=1)
			Result:=RTrim(temp,OptionOmitChars)
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),Result)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	

	
	return
}
getNameActionTrim_a_string()
{
	return lang("Trim_a_string")
}
getCategoryActionTrim_a_string()
{
	return lang("Variable")
}

getParametersActionTrim_a_string()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello World|VarValue","Label|" lang("Options"),"Radio|1|TrimWhat|" lang("Remove a number of characters") ";" lang("Remove specific caracters"), "Label|" lang("Remove from whitch side"),"CheckBox|1|LeftSide|" lang("Left-hand side"),"CheckBox|0|RightSide|" lang("Right-hand side"),"Label|" lang("Count of characters"),"Text|6|Length","Label|" lang("Whitch characters"),"CheckBox|1|SpacesAndTabs|" lang("Spaces and tabs"),"Text|%a_space%%a_tab%|OmitChars"]
	
	return parametersToEdit
}

GenerateNameActionTrim_a_string(ID)
{
	global
	
	return % lang("Trim_a_string") "`n" GUISettingsOfElement%ID%Varname ", " GUISettingsOfElement%ID%VarValue
	
}

CheckSettingsActionTrim_a_string(ID)
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