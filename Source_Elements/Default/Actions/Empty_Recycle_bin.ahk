;Always add this element class name to the global list
x_RegisterElementClass("Action_Empty_Recycle_Bin")

;Element type of the element
Element_getElementType_Action_Empty_Recycle_Bin()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Empty_Recycle_Bin()
{
	return x_lang("Empty_Recycle_Bin")
}

;Category of the element
Element_getCategory_Action_Empty_Recycle_Bin()
{
	return x_lang("Drive")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Empty_Recycle_Bin()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Empty_Recycle_Bin()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Empty_Recycle_Bin()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Empty_Recycle_Bin()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Empty_Recycle_Bin(Environment)
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
	
	parametersToEdit.push({type: "Label", label: x_lang("Which drive")})
	parametersToEdit.push({type: "Radio", id: "AllDrives", default: "All", result: "enum", choices: [x_lang("All drives"), x_lang("Specified drive")], enum: ["All", "Specified"]})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultdrive, choices: listOfdrives})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Empty_Recycle_Bin(Environment, ElementParameters)
{
	switch (ElementParameters.AllDrives)
	{
		case "All":
		driveText := x_lang("All drives")
		case "Specified":
		driveText := ElementParameters.DriveLetter
	}
	return x_lang("Empty_Recycle_Bin") " - " driveText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Empty_Recycle_Bin(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.AllDrives = "All")
	{
		x_Par_Disable("DriveLetter")
	}
	else
	{
		x_Par_Enable("DriveLetter")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Empty_Recycle_Bin(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, "DriveLetter")
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.AllDrives = "All")
	{
		; recycle all drives
		FileRecycleEmpty
	}
	else
	{
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["DriveLetter"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		; check whether drive is set
		if not DriveLetter
		{
			x_finish(Environment, "exception", x_lang("Drive is not specified"))
			return
		}

		; recycle the specified drive
		FileRecycleEmpty, % EvaluatedParameters.DriveLetter
	}
	
	; check for errors
	if ErrorLevel
	{
		x_finish(Environment,"exception", x_lang("Recycle bin could not be emptied."))
		return
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Empty_Recycle_Bin(Environment, ElementParameters)
{
	
}





