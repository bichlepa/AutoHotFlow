iniAllActions.="Eject_Drive|" ;Add this action to list of all actions on initialisation

runActionEject_Drive(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local Result
	local String
	
	
	
	local DriveLetter:=v_replaceVariables(InstanceID,ThreadID,%ElementID%DriveLetter)
	if DriveLetter=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive letter is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Drive letter")))
		return
	}
	
	
	if (%ElementID%WhatDo=1) 
	{
		if (%ElementID%Method=1) 
		{
			Result:=Eject( DriveLetter  )
			;~ ToolTip %ErrorLevel% %a_lasterror%
			if (ErrorLevel<0)
			{
				if (ErrorLevel=-1)
					String:="Invalid drive letter"
				else if (ErrorLevel=-2)
				{
					String:="Neither a CD/DVD drive, nor a USB Mass Storage device."
				}
				else if (ErrorLevel=-3)
				{
					if (a_lasterror=1)
						String:="The specified operation was rejected for an unknown reason."
					if (a_lasterror=2)
						String:="The device does not support the specified PnP operation."
					if (a_lasterror=3)
						String:="The specified operation cannot be completed because of a pending close operation."
					if (a_lasterror=4)
						String:="A Microsoft Win32 application vetoed the specified operation."
					if (a_lasterror=5)
						String:="A Win32 service vetoed the specified operation."
					if (a_lasterror=6)
						String:="The requested operation was rejected because of outstanding open handles."
					if (a_lasterror=7)
						String:="The device supports the specified operation, but the device rejected the operation."
					if (a_lasterror=8)
						String:="The driver supports the specified operation, but the driver rejected the operation."
					if (a_lasterror=9)
						String:="The device does not support the specified operation."
					if (a_lasterror=10)
						String:="There is insufficient power to perform the requested operation."
					if (a_lasterror=11)
						String:="The device cannot be disabled."
					if (a_lasterror=12)
						String:="The driver does not support the specified PnP operation."
					if (a_lasterror=13)
						String:="The caller has insufficient privileges to complete the operation."
				}
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive " DriveLetter " could not be ejected." String)
				
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Drive %1% could not be ejected",DriveLetter) " - " lang("Error description") ": " String)
				return
				
				
			}
		}
		else if (%ElementID%Method=2)
		{
			local hVolume := DllCall("CreateFile"
			, Str, "\\.\" . Driveletter
			, UInt, 0x80000000 | 0x40000000  ; GENERIC_READ | GENERIC_WRITE
			, UInt, 0x1 | 0x2  ; FILE_SHARE_READ | FILE_SHARE_WRITE
			, UInt, 0
			, UInt, 0x3  ; OPEN_EXISTING
			, UInt, 0, UInt, 0)
			if hVolume <> -1
			{
				DllCall("DeviceIoControl"
					, UInt, hVolume
					, UInt, 0x2D4808   ; IOCTL_STORAGE_EJECT_MEDIA
					, UInt, 0, UInt, 0, UInt, 0, UInt, 0
					, UIntP, dwBytesReturned  ; Unused.
					, UInt, 0)
				DllCall("CloseHandle", UInt, hVolume)
			}
			
			if ErrorLevel
			{
				
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive " DriveLetter " could not be ejected.")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Drive %1% could not be ejected",DriveLetter))
				return
				
				
			}
		}
		else if (%ElementID%Method=2)
		{
			drive,eject,% DriveLetter
			if ErrorLevel
			{
				
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive " DriveLetter " could not be ejected.")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Drive %1% could not be ejected",DriveLetter))
				return
				
				
			}
		}
		
	}
	else
	{
		drive,eject,% DriveLetter,1
			if ErrorLevel
		{
			
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Drive " DriveLetter " could not be retracted.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Drive %1% could not be retracted",DriveLetter))
			return
			
			
		}
	}
	
	
	
	
	v_SetVariable(InstanceID,ThreadID,Varname,tempResult)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionEject_Drive()
{
	return lang("Eject_Drive")
}
getCategoryActionEject_Drive()
{
	return lang("Drive")
}

getParametersActionEject_Drive(shouldInitialize = false)
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
	
	parametersToEdit.push({type: "Label", label: lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", default: defaultdrive, choices: listOfdrives, result: "name"})
	
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "WhatDo", default: 1, choices: [lang("Eject drive"), lang("Retract the tray of CD or DVD drive") ] })
	
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: 1, choices: [lang("Method %1%",1), lang("Method %1%",2) " ("  lang("Force")  ")" , lang("Method %1%",3) " ("  lang("Only CD or DVD drive")  ")" ] })
	
	return parametersToEdit
}

GenerateNameActionEject_Drive(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Eject_Drive") " - " GUISettingsOfElement%ID%DriveLetter
	
	
}

CheckSettingsActionEject_Drive(ID)
{
	global
	if (GUISettingsOfElement%ID%WhatDo1 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Method1
		GuiControl,Enable,GUISettingsOfElement%ID%Method2
		GuiControl,Enable,GUISettingsOfElement%ID%Method3
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Method1
		GuiControl,Disable,GUISettingsOfElement%ID%Method2
		GuiControl,Disable,GUISettingsOfElement%ID%Method3
	}
	
}


