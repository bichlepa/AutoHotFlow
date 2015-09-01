iniAllActions.="Substring|" ;Add this action to list of all actions on initialisation

runActionSubstring(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	local OptionToLeft
	local OptionLength:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Length)
	if OptionLength is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Length is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Length")))
		return
	}
	local OptionStartPos


	
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	
	if temp=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Input string is empty")
	}
	
	
	if %ElementID%WhereToBegin=1 ;Begin from left
	{
		
		StringLeft,Result,temp,%ElementID%Length
		v_SetVariable(InstanceID,ThreadID,Varname,Result)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else if %ElementID%WhereToBegin=2 ;Begin from right
	{
		StringRight,Result,temp,% %ElementID%Length
		v_SetVariable(InstanceID,ThreadID,Varname,Result)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else if %ElementID%WhereToBegin=3 ;Begin from middle
	{
		OptionStartPos:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%StartPos)
		if OptionStartPos is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Start position is not a number.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Start position")))
			return
		}
		
		
		if %ElementID%LeftOrRight=1 ;Go left
		{
			OptionToLeft=L
		}
		if  %ElementID%UntilTheEnd=0
		{
			OptionLength:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Length) 
			Stringmid,Result,temp,% OptionStartPos,%OptionLength%,%OptionToLeft%
		}
		else
		{
			Stringmid,Result,temp,% OptionStartPos,,%OptionToLeft%
		}
		
		
		v_SetVariable(InstanceID,ThreadID,Varname,Result)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Unexpected error.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected error"))
		return
	}

	
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: "StringOrExpression", contentParID: "isExpression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Start position")})
	parametersToEdit.push({type: "Radio", id: "WhereToBegin", default: 1, choices: [lang("Begin from left"), lang("Begin from right"), lang("Start from following position")]})
	parametersToEdit.push({type: "Edit", id: "StartPos", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Count of characters")})
	parametersToEdit.push({type: "CheckBox", id: "UntilTheEnd", default: 0, label: lang("Until the end")})
	parametersToEdit.push({type: "Edit", id: "Length", default: 5, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "LeftOrRight", default: 1, choices: [lang("Go left"), lang("Go right")]})

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