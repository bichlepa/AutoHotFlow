iniAllActions.="Get_from_list|" ;Add this action to list of all actions on initialisation

runActionGet_from_list(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local Varname:=v_replaceVariables(InstanceID,%ElementID%Varname)
	local ListName:=v_replaceVariables(InstanceID,%ElementID%ListName)
	local Position:=v_replaceVariables(InstanceID,%ElementID%Position)
	local tempObject:=v_getVariable(InstanceID,ListName,"list")
	
	
	if IsObject(tempObject)
	{
		if %ElementID%WhitchPosition=1 ;first item
		{
			if (tempObject.MinIndex()!="")
			{
				Result:=tempObject[tempObject.MinIndex()]
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
			}
			else
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
		}
		else if %ElementID%WhitchPosition=2 ;Last item
		{
			if (tempObject.MaxIndex()!="")
			{
				Result:=tempObject[tempObject.MaxIndex()]
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
			}
			else
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
		}
		else if %ElementID%WhitchPosition=3 ;Random item
		{
			
			if (tempObject.MaxIndex()!="")
			{
				random,temp,tempObject.MinIndex(),tempObject.MaxIndex()
				Result:=tempObject[temp]
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
			}
			else
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
		}
		else if %ElementID%WhitchPosition=4 ;Specified item
		{
			if Position!=""
			{
				Result:=tempObject[Position]
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
			}
			else
			{
				MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
				
			}
		}
		v_SetVariable(InstanceID,Varname,Result)
		
		
		
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	

	return
}
getNameActionGet_from_list()
{
	return lang("Get_from_list")
}
getCategoryActionGet_from_list()
{
	return lang("Variable")
}

getParametersActionGet_from_list()
{
	global
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|NewVariable|Varname","Label|" lang("Input list name"),"VariableName|List|ListName","Radio|3|WhitchPosition|" lang("First position") ";" lang("Last position")";" lang("Random position") ";" lang("Following position or key"),"text|2|Position"]
	
	return parametersToEdit
}

GenerateNameActionGet_from_list(ID)
{
	global
	
	return % lang("Get_from_list") "`n" GUISettingsOfElement%ID%Varname 
	
}

CheckSettingsActionGet_from_list(ID)
{
	if (GUISettingsOfElement%ID%WhitchPosition4 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Position
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
}