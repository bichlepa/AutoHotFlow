;Always add this element class name to the global list
x_RegisterElementClass("Action_Lock_Or_Unlock_Drive")

;Element type of the element
Element_getElementType_Action_Lock_Or_Unlock_Drive()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Lock_Or_Unlock_Drive()
{
	return x_lang("Lock_Or_Unlock_Drive")
}

;Category of the element
Element_getCategory_Action_Lock_Or_Unlock_Drive()
{
	return x_lang("Drive")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Lock_Or_Unlock_Drive()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Lock_Or_Unlock_Drive()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Lock_Or_Unlock_Drive()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Lock_Or_Unlock_Drive()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Lock_Or_Unlock_Drive(Environment)
{
	static listOfdrives
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
	
	parametersToEdit.push({type: "Label", label: x_lang("Action")})
	parametersToEdit.push({type: "Radio", id: "WhatDo", default: 1, choices: [x_lang("Lock drive"), x_lang("Unlock drive")], result: "enum", enum: ["Lock", "Unlock"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "string", default: defaultdrive, choices: listOfdrives, result: "string"})
	
	; request that the result of this function is never cached (because of the drive letter list)
	parametersToEdit.updateOnEdit := true
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{
	switch (ElementParameters.WhatDo)
	{
		case "Lock":
		WhatDoString := x_lang("Lock")
		case "Unlock":
		WhatDoString := x_lang("Unlock")
	}
	
	return x_lang("Lock_Or_Unlock_Drive") " - " WhatDoString " - " ElementParameters.DriveLetter
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check whether parameter is specified
	if (not EvaluatedParameters.DriveLetter)
	{
		x_finish(Environment, "exception", x_lang("Drive is not specified"))
		return
	}

	; lock or unlock drive
	if (EvaluatedParameters.WhatDo = "Lock")
	{
		drive, lock, % EvaluatedParameters.DriveLetter
	
		; check for errors
		if ErrorLevel
		{
			x_finish(Environment, "exception", x_lang("Could not lock drive '%1%'", Path))
			return
		}
	}
	Else if (EvaluatedParameters.WhatDo = "Unlock")
	{
		drive, unlock, % EvaluatedParameters.DriveLetter
	
		; check for errors
		if ErrorLevel
		{
			x_finish(Environment, "exception", x_lang("Could not unlock drive '%1%'", Path))
			return
		}
	}

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Lock_Or_Unlock_Drive(Environment, ElementParameters)
{
}






