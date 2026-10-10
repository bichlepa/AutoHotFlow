
;Name of the element
Element_getName_Action_Eject_Drive()
{
	return x_lang("Eject_Drive")
}

;Category of the element
Element_getCategory_Action_Eject_Drive()
{
	return x_lang("Drive")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Eject_Drive()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Eject_Drive()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Eject_Drive()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Eject_Drive(Environment)
{
	parametersToEdit:=Object()
	
	; get list of drive letters
	listOfdrives := Object()
	driveget, tempdrives,list
	
	loop, parse, tempdrives
	{
		if (a_index = 1)
			defaultdrive := A_LoopField ":"
		listOfdrives.push(A_LoopField ":")
	}
	
	parametersToEdit.push({type: "Label", label: x_lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultdrive, choices: listOfdrives})
	
	parametersToEdit.push({type: "Label", label: x_lang("Action")})
	parametersToEdit.push({type: "Radio", id: "WhatDo", default: "ejectDrive", result: "enum", choices: [x_lang("Eject drive"), x_lang("Retract the tray of a optical disc drive") ], enum: ["ejectDrive", "RetractTray"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: "LibraryEjectByScan", result: "enum", choices: [x_lang("Method %1%", 1), x_lang("Method %1%", 2) " ("  x_lang("Force #verb")  ")", x_lang("Method %1%", 3) " ("  x_lang("Only optical disc drive")  ")" ], enum: ["LibraryEjectByScan", "DeviceIoControl", "builtIn"]})
	
	; request that the result of this function is never cached (because of the drive letter list)
	parametersToEdit.updateOnEdit := true
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Eject_Drive(Environment, ElementParameters)
{
	switch (ElementParameters.WhatDo)
	{
		case "ejectDrive":
		WhatDoString := x_lang("Eject drive")
		case "RetractTray":
		WhatDoString := x_lang("Retract the tray of a optical disc drive")
	}

	return x_lang("Eject_Drive") " - " WhatDoString " - " ElementParameters.DriveLetter
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Eject_Drive(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.WhatDo = "ejectDrive")
	{
		x_Par_Enable("Method")
	}
	else
	{
		x_Par_Disable("Method")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Eject_Drive(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check whether drive is set
	if (not EvaluatedParameters.DriveLetter)
	{
		x_finish(Environment, "exception", x_lang("Drive is not specified"))
		return
	}
	
	if (EvaluatedParameters.WhatDo = "ejectDrive") 
	{
		; user wants to eject a drive

		if (EvaluatedParameters.Method = "LibraryEjectByScan") 
		{
			; we will try the Eject library of Scan

			; eject now
			Result := Default_Lib_Eject(EvaluatedParameters.DriveLetter)
			
			; check for errors
			if (ErrorLevel < 0)
			{
				; an error occured. Return error description
				if (ErrorLevel = -1)
				{
					String := "Invalid drive letter"
				}
				else if (ErrorLevel = -2)
				{
					String := "Neither a CD/DVD drive, nor a USB Mass Storage device."
				}
				else if (ErrorLevel = -3)
				{
					if (a_lasterror = 1)
						String := "The specified operation was rejected for an unknown reason."
					if (a_lasterror = 2)
						String := "The device does not support the specified PnP operation."
					if (a_lasterror = 3)
						String := "The specified operation cannot be completed because of a pending close operation."
					if (a_lasterror = 4)
						String := "A Microsoft Win32 application vetoed the specified operation."
					if (a_lasterror = 5)
						String := "A Win32 service vetoed the specified operation."
					if (a_lasterror = 6)
						String := "The requested operation was rejected because of outstanding open handles."
					if (a_lasterror = 7)
						String := "The device supports the specified operation, but the device rejected the operation."
					if (a_lasterror = 8)
						String := "The driver supports the specified operation, but the driver rejected the operation."
					if (a_lasterror = 9)
						String := "The device does not support the specified operation."
					if (a_lasterror = 10)
						String := "There is insufficient power to perform the requested operation."
					if (a_lasterror = 11)
						String := "The device cannot be disabled."
					if (a_lasterror = 12)
						String := "The driver does not support the specified PnP operation."
					if (a_lasterror = 13)
						String := "The caller has insufficient privileges to complete the operation."
				}
				
				x_finish(Environment, "exception", x_lang("Drive %1% could not be ejected", EvaluatedParameters.DriveLetter) " - " x_lang("Error description") ": " String)
				return
			}
		}
		else if (EvaluatedParameters.Method = "DeviceIoControl")
		{
			; we will try the alternate ejection method from the AHK help

			hVolume := DllCall("CreateFile"
			, Str, "\\.\" . EvaluatedParameters.DriveLetter
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
			
			; check for errors
			if ErrorLevel
			{
				x_finish(Environment, "exception", x_lang("Drive %1% could not be ejected", EvaluatedParameters.DriveLetter))
				return
			}
		}
		else if (EvaluatedParameters.Method = "builtIn")
		{
			; we will try the built in AHK function. It works only on optical disk drives

			; eject
			drive, eject, % EvaluatedParameters.DriveLetter

			; check for errors
			if ErrorLevel
			{
				x_finish(Environment, "exception", x_lang("Drive %1% could not be ejected", EvaluatedParameters.DriveLetter))
				return
			}
		}
	}
	else if (EvaluatedParameters.WhatDo = "RetractTray") 
	{
		; user wants to retract an optical disk drive

		; retract drive
		drive, eject, % EvaluatedParameters.DriveLetter, 1
		
		; check for errors
		if ErrorLevel
		{
			x_finish(Environment, "exception", x_lang("Drive %1% could not be retracted", EvaluatedParameters.DriveLetter))
			return
		}
	}
	
	; if we are here, everything worked.
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Eject_Drive(Environment, ElementParameters)
{
	
}





