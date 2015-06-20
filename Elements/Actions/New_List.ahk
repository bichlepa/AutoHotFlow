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
	else
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
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewList|Varname","Label|" lang("Number of elements"),"Radio|1|InitialContent|" lang("Empty list") ";" lang("Initialize with one element") ";" lang("Initialize with multiple elements"),"Label| " lang("Initial content"),"Radio|1|isExpression|" lang("This is a value") ";" lang("This is a variable name or expression"),"Text|NewElement|VarValue","MultiLineText|Element one`nElement two|VarValues","Checkbox|1|DelimiterLinefeed|" lang("Use linefeed as delimiter") ,"Checkbox|0|DelimiterComma|" lang("Use comma as delimiter") ,"Checkbox|0|DelimiterSemicolon|" lang("Use semicolon as delimiter") ,"Checkbox|0|DelimiterSpace|" lang("Use space as delimiter"),"Label|" lang("Key"),"Radio|1|WhitchPosition|" lang("Numerically as first element") ";" lang("Following key"),"text|keyName|Position"]
	
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