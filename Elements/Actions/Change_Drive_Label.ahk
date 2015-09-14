iniAllActions.="Change_Drive_Label|" ;Add this action to list of all actions on initialisation

runActionChange_Drive_Label(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempResult
	
	
	
	local DriveLetter:=v_replaceVariables(InstanceID,ThreadID,%ElementID%DriveLetter)
	if DriveLetter=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive letter is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Drive letter")))
		return
	}
	
	local NewLabel:=v_replaceVariables(InstanceID,ThreadID,%ElementID%NewLabel) ;"Content" is the parameter ID
	;~ MsgBox %DriveLetter% %NewLabel%
	drive,label,%DriveLetter%,%NewLabel%
	
	if ErrorLevel
	{
		
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Label " NewLabel " could not be set to drive " DriveLetter " could not be locked.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Label %1% could not be set to drive %2%",NewLabel,DriveLetter))
		return
		
		
		
	}
	
	
	v_SetVariable(InstanceID,ThreadID,Varname,tempResult)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionChange_Drive_Label()
{
	return lang("Change_Drive_Label")
}
getCategoryActionChange_Drive_Label()
{
	return lang("Drive")
}

getParametersActionChange_Drive_Label(shouldInitialize = false)
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
		;~ MsgBox %listOfdrives% %defaultdrive%
	}
	
	
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", id: "DriveLetterLabel", label: lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", default: defaultdrive, choices: listOfdrives, result: "name"})
	
	parametersToEdit.push({type: "Label", label: lang("New label")})
	parametersToEdit.push({type: "edit", id: "NewLabel", content: "String"})
	

	return parametersToEdit
}

GenerateNameActionChange_Drive_Label(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Change_Drive_Label") " - " GUISettingsOfElement%ID%DriveLetter " - " GUISettingsOfElement%ID%NewLabel
	
	
}

CheckSettingsActionChange_Drive_Label(ID)
{
	global
	
	
}



