;Always add this element class name to the global list
x_RegisterElementClass("Action_Time_Calculation")

;Element type of the element
Element_getElementType_Action_Time_Calculation()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Time_Calculation()
{
	return x_lang("Time_Calculation")
}

;Category of the element
Element_getCategory_Action_Time_Calculation()
{
	return x_lang("Time")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Time_Calculation()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Time_Calculation()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Time_Calculation()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Time_Calculation()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Time_Calculation(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "CalculatedTime", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input time")})
	parametersToEdit.push({type: "Edit", id: "InputTime", default: "InputTime", content: "Expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Time to add")})
	parametersToEdit.push({type: "Edit", id: "Units", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Which unit"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [x_lang("Seconds"), x_lang("Minutes"), x_lang("Hours"), x_lang("Days")], enum: ["Seconds", "Minutes", "Hours", "Days"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Time_Calculation(Environment, ElementParameters)
{
	switch (ElementParameters.Unit)
	{
		case "MilliSeconds":
		unitText := x_lang("Milliseconds")
		case "Seconds":
		unitText := x_lang("Seconds")
		case "Minutes":
		unitText := x_lang("Minutes")
	}
	return x_lang("Time_Calculation") " - " ElementParameters.Varname  " = " ElementParameters.InputTime " + " ElementParameters.Units " " unitText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Time_Calculation(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Time_Calculation(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check input time value
	InputTime := EvaluatedParameters.InputTime
	if InputTime is not time
	{
		x_finish(Environment, "exception", x_lang("Input time is not a time: '%1%'.", InputTime)) 
		return
	}
	
	; check units value
	Units := EvaluatedParameters.Units
	if Units is not number
	{
		x_finish(Environment, "exception", x_lang("Value is not a number: %1%", Units))
		return 
	}
	
	; add time
	envadd, InputTime, % Units, % EvaluatedParameters.Unit

	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, InputTime)
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Time_Calculation(Environment, ElementParameters)
{
	
}






