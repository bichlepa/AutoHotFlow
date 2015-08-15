iniAllConditions.="List_contains_element|" ;Add this condition to list of all conditions on initialisation

runConditionList_contains_element(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempkey
	local tempvalue
	local found
	local foundkey

	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local SearchPosition:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Position)
	local tempObject:=v_getVariable(InstanceID,ThreadID,Varname,"list")
	
	if %ElementID%isExpressionSearchContent=1
		SearchContent:=v_replaceVariables(InstanceID,ThreadID,%ElementID%SearchContent)
	else
		SearchContent:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%SearchContent)
	
	
	found:=false
	if not IsObject(tempObject)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" Varname "' does not contain a list.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' does not contain a list.",Varname))
		return
	}
	
	if (%ElementID%SearchWhat=1) ;search for an index or key
	{
		for tempkey, tempvalue in tempObject
		{
			if (tempkey=SearchPosition)
			{
				found:=true
				break
			}
		}
		if (found=true)
		{
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		}
		else
		{
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
		
	}
	else  ;search for a value
	{
		for tempkey, tempvalue in tempObject
		{
			
			if (tempvalue=SearchContent)
			{
				found:=true
				foundkey:=tempkey
				break
			}
		}
		if (found=true)
		{
			v_setVariable(InstanceID,ThreadID,"a_FoundKey",foundkey,,true)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		}
		else
		{
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		}
		
	}
	
	
	
	
		
	 
	
}

stopConditionList_contains_element(ID)
{
	
	return
}


getParametersConditionList_contains_element()
{
	
	parametersToEdit:=["Label|" lang("List name"),"VariableName|List|Varname","Label|" lang("Search for what"),"Radio|2|SearchWhat|" lang("Search for an index or key") ";" lang("Search for an element with a specific content"),"Label|" lang("Key or index"),"text|1|Position","Label|" lang("Content"),"Radio|1|isExpressionSearchContent|" lang("This is a value") ";" lang("This is a variable name or expression"),"Text|Any element|SearchContent"]
	
	return parametersToEdit
}

getNameConditionList_contains_element()
{
	return lang("List_contains_element")
}

getCategoryConditionList_contains_element()
{
	return lang("Variable")
}

GenerateNameConditionList_contains_element(ID)
{
	return lang("List_contains_element") 
	
}


CheckSettingsConditionList_contains_element(ID)
{
	if (GUISettingsOfElement%ID%SearchWhat1 = 1) ;Search for an index or key
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Position
		GuiControl,Disable,GUISettingsOfElement%ID%isExpressionSearchContent1
		GuiControl,Disable,GUISettingsOfElement%ID%isExpressionSearchContent2
		GuiControl,Disable,GUISettingsOfElement%ID%SearchContent
	}
	else ;Multiple elements
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Position
		GuiControl,Enable,GUISettingsOfElement%ID%isExpressionSearchContent1
		GuiControl,Enable,GUISettingsOfElement%ID%isExpressionSearchContent2
		GuiControl,Enable,GUISettingsOfElement%ID%SearchContent
		
		
	}
	
	
	
	
	
}