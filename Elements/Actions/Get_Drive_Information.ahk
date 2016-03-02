iniAllActions.="Get_Drive_Information|" ;Add this action to list of all actions on initialisation

runActionGet_Drive_Information(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempResult
	
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname) ;"Content" is the parameter ID
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Variable name '%1%'",varname)) )
		return
	}
	
	
	
	
	if (%ElementID%WhichInformation=1 or %ElementID%WhichInformation=4 or %ElementID%WhichInformation=7 or %ElementID%WhichInformation=8) ;Label, CD status, Serial, Filesystem
	{
		local DriveLetter:=v_replaceVariables(InstanceID,ThreadID,%ElementID%DriveLetter)
		if DriveLetter=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive letter is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Drive letter")))
			return
		}
		tempType:=%ElementID%DriveType
	}
	else
	{
		local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
		
		if tempPath=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Folder path not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Folder path")))
			return
		}
		
		if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
			tempPath:=flowSettings.WorkingDir "\" tempPath
		
		
		
	}
	if (%ElementID%WhichInformation=1) ;Label
	{
		driveget, tempResult,label,%DriveLetter%
	}
	else if (%ElementID%WhichInformation=2) ;Type
	{
		driveget, tempResult,type,%tempPath%
	}
	else if (%ElementID%WhichInformation=3) ;Status
	{
		driveget, tempResult,status,%tempPath%
	}
	else if (%ElementID%WhichInformation=4) ;Status or CD
	{
		driveget, tempResult,statusCD,%DriveLetter%
	}
	else if (%ElementID%WhichInformation=5) ;Capacity
	{
		driveget, tempResult,Capacity,%tempPath%
	}
	else if (%ElementID%WhichInformation=6)  ;Free space
	{
		DriveSpaceFree, tempResult,%tempPath%
	}
	else if (%ElementID%WhichInformation=7) ;file system
	{
		driveget, tempResult,Filesystem ,%DriveLetter%
	}
	else if (%ElementID%WhichInformation=8) ;Serial number
	{
		driveget, tempResult,Serial ,%DriveLetter%
	}
	if ErrorLevel
	{
		if %ElementID%IfNothingFound=2
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! An error occured.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("An error occured",tempPath))
			return
		}
	}
	
	
	v_SetVariable(InstanceID,ThreadID,Varname,tempResult)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionGet_Drive_Information()
{
	return lang("Get_Drive_Information")
}
getCategoryActionGet_Drive_Information()
{
	return lang("Drive")
}

getParametersActionGet_Drive_Information(shouldInitialize = false)
{
	global
	
	if shouldInitialize 
	{
		local listOfdrives:=Object()
		local tempdrives
		local defaultdrive
		driveget, tempdrives,list
		
		loop,parse,tempdrives
		{
			if a_index=1
				defaultdrive:=A_LoopField ":"
			listOfdrives.push(A_LoopField ":")
			
		}
	}
	
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "DriveInfo", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Which information")})
	parametersToEdit.push({type: "dropdown", id: "WhichInformation", default: 1, choices: [lang("Label"), lang("Type"), lang("Status"), lang("Status of CD or DVD drive"), lang("Capacity"), lang("Free disk space"), lang("File system"), lang("Serial number")], result: "number" })
	
	parametersToEdit.push({type: "Label", id: "DriveLetterLabel", label: lang("Drive letter or UNC name")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", default: defaultdrive, choices: listOfdrives, result: "name"})
	
	parametersToEdit.push({type: "Label", label: lang("Path")})
	parametersToEdit.push({type: "Folder", id: "folder", label: lang("Select a folder")})

	return parametersToEdit
}

GenerateNameActionGet_Drive_Information(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Get_Drive_Information") " - " GUISettingsOfElement%ID%Varname
	
	
}

CheckSettingsActionGet_Drive_Information(ID)
{
	global
	if (GUISettingsOfElement%ID%WhichInformation = 1 or GUISettingsOfElement%ID%WhichInformation = 4 or GUISettingsOfElement%ID%WhichInformation = 7 or GUISettingsOfElement%ID%WhichInformation = 8)
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%folder
		GuiControl,Enable,GUISettingsOfElement%ID%DriveLetter
		if (GUISettingsOfElement%ID%WhichInformation = 4)
		{
			guicontrol,,GUISettingsOfElement%ID%DriveLetterLabel,% lang("Drive letter")
		}
		else
		{
			guicontrol,,GUISettingsOfElement%ID%DriveLetterLabel,% lang("Drive letter or UNC name")
		}
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%folder
		GuiControl,Disable,GUISettingsOfElement%ID%DriveLetter
	}
	
}
