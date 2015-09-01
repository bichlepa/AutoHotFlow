iniAllActions.="New_list|" ;Add this action to list of all actions on initialisation

runActionNew_list(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local varvalue:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varvalue)
	local varvalues:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varvalues)
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local Position:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Position)
	local temp
	local templist
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	
	if not v_CheckVariableName(Varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! List name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("List name '%1%'",varname)) )
		return
	}
	
	if (%ElementID%InitialContent=1) ;empty list
	{
		v_SetVariable(InstanceID,ThreadID,Varname,Object(),"list")
		
	}
	else if (%ElementID%InitialContent=2) ;one element
	{
		if %ElementID%isExpression=1
			temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
		else
			temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
		templist:=Object()
		if %ElementID%WhitchPosition=1 ;Stupid misspelling :-(
		{
			templist.insert(temp)
		}
		else
		{
			templist.insert(Position,temp)
		}
		
		v_SetVariable(InstanceID,ThreadID,Varname,templist,"list")
	}
	else ;multiple elements
	{
		if %ElementID%DelimiterLinefeed
			StringReplace,varvalues,varvalues,`n,▬,all
		if %ElementID%DelimiterComma
			StringReplace,varvalues,varvalues,`,,▬,all
		if %ElementID%DelimiterSemicolon
			StringReplace,varvalues,varvalues,;,▬,all
		if %ElementID%DelimiterSpace
			StringReplace,varvalues,varvalues,%A_Space%,▬,all
		templist:=Object()
		loop,parse,varvalues,▬
		{
			templist.Insert(A_Index,A_LoopField)
		}
		
		v_SetVariable(InstanceID,ThreadID,Varname,templist,"list")
	}
		
	
	
	

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionNew_list()
{
	return lang("New_list")
}
getCategoryActionNew_list()
{
	return lang("Variable")
}

getParametersActionNew_list()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Number of elements")})
	parametersToEdit.push({type: "Radio", id: "InitialContent", default: 1, choices: [lang("Empty list"), lang("Initialize with one element"), lang("Initialize with multiple elements")]})
	parametersToEdit.push({type: "Label", label:  lang("Initial content")})
	parametersToEdit.push({type: "Radio", id: "isExpression", default: 1, choices: [lang("This is a value"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: "StringOrExpression", contentParID: "isExpression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Edit", id: "VarValues", default: "Element one`nElement two", multiline: true, content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: lang("Use linefeed as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterComma", default: 0, label: lang("Use comma as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: lang("Use semicolon as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSpace", default: 0, label: lang("Use space as delimiter")})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Radio", id: "WhitchPosition", default: 1, choices: [lang("Numerically as first element"), lang("Following key")]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionNew_list(ID)
{
	global
	local Text
	
	if GUISettingsOfElement%ID%InitialContent1=1
	{
		Text.= lang("New empty list") " " GUISettingsOfElement%ID%Varname
	}
	else if GUISettingsOfElement%ID%InitialContent2=1
	{
		Text.= lang("New list %1% with initial content",GUISettingsOfElement%ID%Varname) ": "
		Text.=  GUISettingsOfElement%ID%VarValue
		
	}
	else
	{
		Text.= lang("New list %1% with initial content",GUISettingsOfElement%ID%Varname) ": "
		Text.=  GUISettingsOfElement%ID%VarValues
		
	}
	
	return Text
	
}

CheckSettingsActionNew_list(ID)
{
	if (GUISettingsOfElement%ID%InitialContent1 = 1) ;Empty list
	{
		GuiControl,Disable,GUISettingsOfElement%ID%isExpression1
		GuiControl,Disable,GUISettingsOfElement%ID%isExpression2
		GuiControl,Disable,GUISettingsOfElement%ID%VarValue
		GuiControl,Disable,GUISettingsOfElement%ID%VarValues
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterLinefeed
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterComma
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterSemicolon
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterSpace
		GuiControl,Disable,GUISettingsOfElement%ID%WhitchPosition1
		GuiControl,Disable,GUISettingsOfElement%ID%WhitchPosition2
		GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
	else if (GUISettingsOfElement%ID%InitialContent2 = 1) ;one element
	{
		GuiControl,Enable,GUISettingsOfElement%ID%isExpression1
		GuiControl,Enable,GUISettingsOfElement%ID%isExpression2
		GuiControl,Enable,GUISettingsOfElement%ID%VarValue
		GuiControl,Disable,GUISettingsOfElement%ID%VarValues
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterLinefeed
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterComma
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterSemicolon
		GuiControl,Disable,GUISettingsOfElement%ID%DelimiterSpace
		GuiControl,Enable,GUISettingsOfElement%ID%WhitchPosition1
		GuiControl,Enable,GUISettingsOfElement%ID%WhitchPosition2
		if (GUISettingsOfElement%ID%WhitchPosition2 = 1)
			GuiControl,Enable,GUISettingsOfElement%ID%Position
		else
			GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
	else ;Multiple elements
	{
		GuiControl,Disable,GUISettingsOfElement%ID%isExpression1
		GuiControl,Disable,GUISettingsOfElement%ID%isExpression2
		GuiControl,Disable,GUISettingsOfElement%ID%VarValue
		GuiControl,Enable,GUISettingsOfElement%ID%VarValues
		GuiControl,Enable,GUISettingsOfElement%ID%DelimiterLinefeed
		GuiControl,Enable,GUISettingsOfElement%ID%DelimiterComma
		GuiControl,Enable,GUISettingsOfElement%ID%DelimiterSemicolon
		GuiControl,Enable,GUISettingsOfElement%ID%DelimiterSpace
		GuiControl,Disable,GUISettingsOfElement%ID%WhitchPosition1
		GuiControl,Disable,GUISettingsOfElement%ID%WhitchPosition2
		GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
	
}