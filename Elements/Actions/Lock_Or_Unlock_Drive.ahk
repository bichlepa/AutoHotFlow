iniAllActions.="Lock_Or_Unlock_Drive|" ;Add this action to list of all actions on initialisation

runActionLock_Or_Unlock_Drive(InstanceID,ThreadID,ElementID,ElementIDInInstance)
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
	
	
	if (%ElementID%WhatDo=1) ;Lock
	{
		drive,lock,% DriveLetter
		
	}
	else ;unlock
	{
		drive,unlock,% DriveLetter
		
	}
	
	if ErrorLevel
	{
		if (%ElementID%WhatDo=1) ;Lock
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive " DriveLetter " could not be locked.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Drive %1% could not be locked",DriveLetter))
			return
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive " DriveLetter " could not be unlocked.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Drive %1% could not be unlocked",DriveLetter))
			return
		}
		
	}
	
	
	v_SetVariable(InstanceID,ThreadID,Varname,tempResult)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionLock_Or_Unlock_Drive()
{
	return lang("Lock_Or_Unlock_Drive")
}
getCategoryActionLock_Or_Unlock_Drive()
{
	return lang("Drive")
}

getParametersActionLock_Or_Unlock_Drive(shouldInitialize = false)
{
	global
	
	if shouldInitialize 
	{
		local listOfdrives:=Object()
		local tempdrives
		local defaultdrive
		driveget, tempdrives,list,CDROM
		
		loop,parse,tempdrives
		{
			if a_index=1
				defaultdrive:=A_LoopField ":"
			listOfdrives.push(A_LoopField ":")
			
		}
		
	}
	
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "WhatDo", default: 1, choices: [lang("Lock drive"), lang("Unlock drive")]})
	
	parametersToEdit.push({type: "Label", id: "DriveLetterLabel", label: lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", default: defaultdrive, choices: listOfdrives, result: "name"})
	

	return parametersToEdit
}

GenerateNameActionLock_Or_Unlock_Drive(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Lock_Or_Unlock_Drive") " - " GUISettingsOfElement%ID%DriveLetter
	
	
}

CheckSettingsActionLock_Or_Unlock_Drive(ID)
{
	global
	
	
}
