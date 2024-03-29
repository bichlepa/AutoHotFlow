﻿
;Name of the element
Element_getName_Action_Change_Drive_Label()
{
	return x_lang("Change_Drive_Label")
}

;Category of the element
Element_getCategory_Action_Change_Drive_Label()
{
	return x_lang("Drive")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Change_Drive_Label()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Change_Drive_Label()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Change_Drive_Label()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Change_Drive_Label(Environment)
{
	parametersToEdit := Object()
	
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

	parametersToEdit.push({type: "Label", label: x_lang("New label")})
	parametersToEdit.push({type: "Edit", id: "NewLabel", content: "String"})
	
	; request that the result of this function is never cached (because of the drive letter list)
	parametersToEdit.updateOnEdit := true
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Change_Drive_Label(Environment, ElementParameters)
{
	return x_lang("Change_Drive_Label") " - " ElementParameters.DriveLetter " - " ElementParameters.NewLabel
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Change_Drive_Label(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Change_Drive_Label(Environment, ElementParameters)
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
	
	; change drive label
	;Admin rights are needed
	drive, label, % EvaluatedParameters.DriveLetter, % EvaluatedParameters.NewLabel
	if ErrorLevel
	{
		; an error occured. Finish with exception.
		x_finish(Environment, "exception", x_lang("Label '%1%'' could not be set to drive '%2%'", EvaluatedParameters.NewLabel, EvaluatedParameters.DriveLetter))
		return
	}
	
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Change_Drive_Label(Environment, ElementParameters)
{
	
}





