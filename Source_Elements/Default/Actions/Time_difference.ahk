
;Name of the element
Element_getName_Action_Time_Difference()
{
	return x_lang("Time_Difference")
}

;Category of the element
Element_getCategory_Action_Time_Difference()
{
	return x_lang("Time")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Time_Difference()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Time_Difference()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Time_Difference()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Time_Difference(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "TimeDifference", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("First input time")})
	parametersToEdit.push({type: "Edit", id: "InputTime", default: "a_now", content: "Expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Second input time")})
	parametersToEdit.push({type: "Edit", id: "InputTime2", default: "InputTime", content: "Expression", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Which unit")})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [x_lang("Seconds"), x_lang("Minutes"), x_lang("Hours"), x_lang("Days")], enum: ["Seconds", "Minutes", "Hours", "Days"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Time_Difference(Environment, ElementParameters)
{
	return x_lang("Time_Difference") " - " ElementParameters.Varname  " = " ElementParameters.InputTime " - " ElementParameters.InputTime2 " - " ElementParameters.Unit
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Time_Difference(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Time_Difference(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check input time values
	InputTime := EvaluatedParameters.InputTime
	if InputTime is not time
	{
		x_finish(Environment, "exception", x_lang("First input time does not contain a time: '%1%'.", InputTime)) 
		return
	}
	InputTime2 := EvaluatedParameters.InputTime2
	if InputTime2 is not time
	{
		x_finish(Environment, "exception", x_lang("Second input time does not contain a time: '%1%'.", InputTime2)) 
		return
	}
	
	; calculate time difference
	envsub, InputTime, % InputTime2, % EvaluatedParameters.Unit
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, InputTime)
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Time_Difference(Environment, ElementParameters)
{
	
}






