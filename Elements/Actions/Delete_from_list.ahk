iniAllActions.="Delete_from_list|" ;Add this action to list of all actions on initialisation

runActionDelete_from_list(InstanceID,ElementID,ElementIDInInstance)
{
	global

	local Varname:=v_replaceVariables(InstanceID,%ElementID%Varname)
	local Position:=v_replaceVariables(InstanceID,%ElementID%Position)
	local tempObject:=v_getVariable(InstanceID,Varname,"list")
	
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	

	
	
	if IsObject(tempObject)
	{
		if %ElementID%WhitchPosition=1
		{
			tempObject.Remove(1)
		}
		else if %ElementID%WhitchPosition=2
		{
			tempObject.Remove(tempObject.MaxIndex())
		}
		else if %ElementID%WhitchPosition=3
		{
			
			tempObject.Remove(Position)
		}
		
		v_SetVariable(InstanceID,Varname,tempObject,"list")
		
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
		
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	

	return
}
getNameActionDelete_from_list()
{
	return lang("Delete_from_list")
}
getCategoryActionDelete_from_list()
{
	return lang("Variable")
}

getParametersActionDelete_from_list()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewList|Varname","Label|" lang("Whitch element"),"Radio|2|WhitchPosition|" lang("First element") ";" lang("Last element")";" lang("Following element or key"),"text|2|Position"]
	
	return parametersToEdit
}

GenerateNameActionDelete_from_list(ID)
{
	global
	if GUISettingsOfElement%ID%WhitchPosition1=1
		return % lang("Delete first element from list %1%", GUISettingsOfElement%ID%Varname )
	if GUISettingsOfElement%ID%WhitchPosition2=1
		return % lang("Delete last element from list %1%", GUISettingsOfElement%ID%Varname )
	if GUISettingsOfElement%ID%WhitchPosition3=1
		return % lang("Delete element %1% from list %2%", GUISettingsOfElement%ID%Position, GUISettingsOfElement%ID%Varname )
	
	
	
}

CheckSettingsActionDelete_from_list(ID)
{
	if (GUISettingsOfElement%ID%WhitchPosition3 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Position
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
}