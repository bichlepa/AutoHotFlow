
;Name of the element
Element_getName_Action_New_Time()
{
	return x_lang("New_Time")
}

;Category of the element
Element_getCategory_Action_New_Time()
{
	return x_lang("Time")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_New_Time()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_New_Time()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_New_Time()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_New_Time(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewTime", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Time")})
	parametersToEdit.push({type: "Radio", id: "WhichTime", default: "Specified", choices: [x_lang("Current time"), x_lang("Specified time")], result: "enum", enum: ["Current", "Specified"]})
	parametersToEdit.push({type: "Dateandtime", id: "Time", id: "Time", default: a_now, format: "DateTime"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_New_Time(Environment, ElementParameters)
{
	switch (ElementParameters.WhichTime)
	{
		case "Current":
		timeText := x_lang("Current time")
		case "Specified":
		timeText := ElementParameters.Time
	}
	return x_lang("New_Time") " - " ElementParameters.Varname " - " timeText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_New_Time(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_New_Time(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.WhichTime = "Current")
	{
		; we want to know current time.
		; set output variable
		x_SetVariable(Environment, EvaluatedParameters.Varname, a_Now)
	}
	else
	{
		; check whether it is a valid time
		NewTime := EvaluatedParameters.Time
		if NewTime is not time
		{
			x_finish(Environment, "exception", x_lang("%1% is not valid.", x_lang("Value '%1%'", NewTime)) )
			return
		}
		; set output variable
		x_SetVariable(Environment, EvaluatedParameters.Varname, NewTime)
	}

	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_New_Time(Environment, ElementParameters)
{
}






