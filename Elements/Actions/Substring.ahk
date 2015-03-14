iniAllActions.="Substring|" ;Add this action to list of all actions on initialisation

runActionSubstring(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local OptionToLeft
	local OptionLength
	local OptionStartPos
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if %ElementID%WhereToBegin=1 ;Begin from left
	{
		
		StringLeft,Result,temp,%ElementID%Length
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),Result)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	else if %ElementID%WhereToBegin=2 ;Begin from right
	{
		StringRight,Result,temp,% %ElementID%Length
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),Result)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	else if %ElementID%WhereToBegin=3 ;Begin from middle
	{
		OptionStartPos:=v_replaceVariables(InstanceID,%ElementID%StartPos) 
		if %ElementID%LeftOrRight=1 ;Go left
		{
			OptionToLeft=L
		}
		if  %ElementID%UntilTheEnd=0
		{
			OptionLength:=v_replaceVariables(InstanceID,%ElementID%Length) 
			Stringmid,Result,temp,% OptionStartPos,%OptionLength%,%OptionToLeft%
		}
		else
		{
			Stringmid,Result,temp,% OptionStartPos,,%OptionToLeft%
		}
		
		
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%Varname),Result)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")

	
	return
}
getNameActionSubstring()
{
	return lang("Substring")
}
getCategoryActionSubstring()
{
	return lang("Variable")
}

getParametersActionSubstring()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input string"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression") ,"Text|Hello World|VarValue","Label|" lang("Options"),"Radio|1|WhereToBegin|" lang("Begin from left") ";" lang("Begin from right") ";" lang("Start somewhere else") , "Label|" lang("Start position"),"Text|1|StartPos","Label|" lang("Count of characters"),"CheckBox|0|UntilTheEnd|" lang("Until the end"),"Text|5|Length","Radio|1|LeftOrRight|" lang("Go left") ";" lang("Go right")]
	
	return parametersToEdit
}

GenerateNameActionSubstring(ID)
{
	global
	
	return % lang("Substring") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

CheckSettingsActionSubstring(ID)
{
	if GUISettingsOfElement%ID%WhereToBegin3=1
	{
		GuiControl,Enable,GUISettingsOfElement%ID%StartPos
		GuiControl,Enable,GUISettingsOfElement%ID%LeftOrRight1
		GuiControl,Enable,GUISettingsOfElement%ID%LeftOrRight2
		GuiControl,Enable,GUISettingsOfElement%ID%UntilTheEnd
		
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%StartPos
		GuiControl,Disable,GUISettingsOfElement%ID%LeftOrRight1
		GuiControl,Disable,GUISettingsOfElement%ID%LeftOrRight2
		GuiControl,Disable,GUISettingsOfElement%ID%UntilTheEnd
		GuiControl,,GUISettingsOfElement%ID%UntilTheEnd,0
	}
	if GUISettingsOfElement%ID%WhereToBegin2=1
	{
		GuiControl,,GUISettingsOfElement%ID%LeftOrRight1,1
	}
	else if GUISettingsOfElement%ID%WhereToBegin1=1
	{
		GuiControl,,GUISettingsOfElement%ID%LeftOrRight2,1
	}
	if (GUISettingsOfElement%ID%UntilTheEnd=1 and GUISettingsOfElement%ID%WhereToBegin3=1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Length
		
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Length
	}
	
}