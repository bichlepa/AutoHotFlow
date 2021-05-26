;Always add this element class name to the global list
x_RegisterElementClass("Action_Eject_Drive")

;Element type of the element
Element_getElementType_Action_Eject_Drive()
{
	return "Action"
}

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

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Eject_Drive()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Eject_Drive()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
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
	
	listOfdrives:=Object()
	driveget, tempdrives,list
	
	loop,parse,tempdrives
	{
		if a_index=1
			defaultdrive:=A_LoopField ":"
		listOfdrives.push(A_LoopField ":")
		
	}
	
	parametersToEdit.push({type: "Label", label: x_lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultdrive, choices: listOfdrives})
	
	parametersToEdit.push({type: "Label", label: x_lang("Action")})
	parametersToEdit.push({type: "Radio", id: "WhatDo", default: "ejectDrive", result: "enum", choices: [x_lang("Eject drive"), x_lang("Retract the tray of a optical disc drive") ], enum: ["ejectDrive", "RetractTray"] })
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: "LibraryEjectByScan", result: "enum", choices: [x_lang("Method %1%",1), x_lang("Method %1%",2) " ("  x_lang("Force")  ")" , x_lang("Method %1%",3) " ("  x_lang("Only optical disc drive")  ")" ], enum: ["LibraryEjectByScan", "DeviceIoControl", "builtIn"]})
	
	
	parametersToEdit.updateOnEdit:=true
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Eject_Drive(Environment, ElementParameters)
{
	return x_lang("Eject_Drive") 
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
	NewLabel := x_replaceVariables(Environment,ElementParameters.NewLabel)
	DriveLetter := x_replaceVariables(Environment, ElementParameters.DriveLetter) 
	
	WhatDo := ElementParameters.WhatDo
	Method := ElementParameters.Method
	
	if not DriveLetter
	{
		x_finish(Environment,"exception", x_lang("Drive is not specified"))
		return
	}
	
	if (WhatDo="ejectDrive") 
	{
		if (Method="LibraryEjectByScan") 
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
				
				x_finish(Environment,"exception", x_lang("Drive %1% could not be ejected",DriveLetter) " - " x_lang("Error description") ": " String)
				return
				
				
			}
		}
		else if (Method="DeviceIoControl")
		{
			hVolume := DllCall("CreateFile"
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
				x_finish(Environment,"exception", x_lang("Drive %1% could not be ejected",DriveLetter))
				
				return
				
				
			}
		}
		else if (Method="builtIn")
		{
			drive,eject,% DriveLetter
			if ErrorLevel
			{
				x_finish(Environment,"exception", x_lang("Drive %1% could not be ejected",DriveLetter))
				return
				
				
			}
		}
		
	}
	else if (WhatDo="RetractTray") 
	{
		drive,eject,% DriveLetter,1
		if ErrorLevel
		{
			x_finish(Environment,"exception", x_lang("Drive %1% could not be retracted",DriveLetter))
			return
			
			
		}
	}
	
	if ErrorLevel
	{
		x_finish(Environment,"exception", x_lang("Label %1% could not be set to drive %2%",NewLabel,DriveLetter))
		return
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Eject_Drive(Environment, ElementParameters)
{
	
}





