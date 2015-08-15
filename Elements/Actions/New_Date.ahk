iniAllActions.="New_date|" ;Add this action to list of all actions on initialisation

runActionNew_date(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempdate:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Date)
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	if %ElementID%WhichDate=1 ;Current date
	{
		v_SetVariable(InstanceID,ThreadID,Varname,a_now,"Date")
		
	}
	else ;Specified date
	{
	if tempdate is not time
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Value '" tempdate "' is not valid")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Value '%1%'",tempdate)) )
			return
			
		}
		
		v_SetVariable(InstanceID,ThreadID,Varname,tempdate,"Date")
	}

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionNew_date()
{
	return lang("New_date")
}
getCategoryActionNew_date()
{
	return lang("Variable")
}

getParametersActionNew_date()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewDate|Varname","Label| " lang("Date"),"Radio|2|WhichDate|" lang("Current date and time") ";" lang("Specified date"),"Dateandtime||Date"]
	
	return parametersToEdit
}

GenerateNameActionNew_date(ID)
{
	global
	
	if (GUISettingsOfElement%ID%WhichDate1 = 1) ;current date
		return % lang("New_date") " - " GUISettingsOfElement%ID%Varname " = " lang("Current date and time")
	else
		return % lang("New_date") " - " GUISettingsOfElement%ID%Varname " = " v_exportVariable(GUISettingsOfElement%ID%Date,"date")
	
}

CheckSettingsActionNew_date(ID)
{
	
	if (GUISettingsOfElement%ID%WhichDate1 = 1) ;current date
	{
		GuiControl,disable,GUISettingsOfElement%ID%Date
	}
	else
	{
		GuiControl,enable,GUISettingsOfElement%ID%Date
	}
	
}