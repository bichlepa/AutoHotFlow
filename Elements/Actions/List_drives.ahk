iniAllActions.="List_Drives|" ;Add this action to list of all actions on initialisation

runActionList_Drives(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempDrives
	local tempType:=""
	local tempobject:=Object()
	
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname) ;"Content" is the parameter ID
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",varname)) )
		return
	}
	
	if %ElementID%WhetherDriveTypeFilter=2
	{
		tempType:=%ElementID%DriveType
	}
	
	driveget, tempDrives,list,%tempType%
	if ErrorLevel
	{
		if %ElementID%IfNothingFound=2
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No drives found.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No drives found",tempPath))
			return
		}
	}
	
	if %ElementID%OutputType=1
	{
		
		loop,parse,tempDrives
		{
			tempobject.push(A_LoopField)
			
		}
		v_SetVariable(InstanceID,ThreadID,Varname,tempObject,"list")
	}
	else
		v_SetVariable(InstanceID,ThreadID,Varname,tempDrives)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionList_Drives()
{
	return lang("List_Drives")
}
getCategoryActionList_Drives()
{
	return lang("Drive")
}

getParametersActionList_Drives()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "DriveList", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Radio", id: "OutputType", default: 1, choices: [lang("Output variable will contain a list"), lang("Output variable will contain a string")]})
	
	parametersToEdit.push({type: "Label", label: lang("Drive type")})
	parametersToEdit.push({type: "Radio", id: "WhetherDriveTypeFilter", default: 1, choices: [lang("Find all drives"), lang("Get only a specific type of drive")]})
	parametersToEdit.push({type: "DropDown", id: "DriveType", default: "CDROM", choices: ["CDROM", "REMOVABLE", "FIXED", "NETWORK", "RAMDISK", "UNKNOWN"], result: "name"})
	
	parametersToEdit.push({type: "Label", label: lang("If no drive can be found")})
	parametersToEdit.push({type: "Radio", id: "IfNothingFound", default: 2, choices: [lang("Normal") " - " lang("Make output variable empty"),lang("Throw exception")]})

	return parametersToEdit
}

GenerateNameActionList_Drives(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("List_Drives") " - " GUISettingsOfElement%ID%Varname
	
}

CheckSettingsActionList_Drives(ID)
{
	global
	if (GUISettingsOfElement%ID%WhetherDriveTypeFilter1 = 1)
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%DriveType
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%DriveType
	}
	
}
