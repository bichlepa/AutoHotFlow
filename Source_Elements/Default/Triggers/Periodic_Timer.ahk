
;Name of the element
Element_getName_Trigger_Periodic_Timer()
{
	return x_lang("Periodic_Timer")
}

;Category of the element
Element_getCategory_Trigger_Periodic_Timer()
{
	return x_lang("Time")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Periodic_Timer()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Trigger_Periodic_Timer()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Periodic_Timer()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Periodic_Timer(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "label", label:  x_lang("Time interval")})
	parametersToEdit.push({type: "edit", id: "Interval", default: 10, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", choices: [x_lang("Milliseconds"), x_lang("Seconds"), x_lang("Minutes")], default: "Seconds", result: "enum", enum: ["MilliSeconds", "Seconds", "Minutes"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Periodic_Timer(Environment, ElementParameters)
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
	return x_lang("Periodic_Timer") " - " ElementParameters.Interval " " unitText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Periodic_Timer(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the trigger is activated
Element_enable_Trigger_Periodic_Timer(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check the interval
	if (not (EvaluatedParameters.Interval > 0))
	{
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "interval", EvaluatedParameters.Interval)) 
		return
	}
	
	; check unit and increase interval if needed
	Interval := EvaluatedParameters.Interval
	switch (EvaluatedParameters.Unit)
	{
	case "MilliSeconds":
		Interval *= 1 ; nothing to do
	case "Seconds":
		Interval *= 1000
	case "Minutes":
		Interval *= 1000 * 60
	default:
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "Unit", EvaluatedParameters.Unit)) 
		return
	}
	
	; We will set a timer which regularely triggers.
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Periodic_Timer_Trigger", EvaluatedParameters)
	x_SetTriggerValue(environment, "functionObject", functionObject)
	SetTimer, % functionObject, % Interval
	
	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Periodic_Timer(Environment, ElementParameters, TriggerData)
{
}

;Called when the trigger should be disabled.
Element_disable_Trigger_Periodic_Timer(Environment, ElementParameters)
{
	; stop the timer
	functionObject := x_GetTriggerValue(environment, "functionObject")
	SetTimer, % functionObject, delete

	x_disabled(Environment, "normal")
}

; Timer Function which triggers the flow
Trigger_Periodic_Timer_Trigger(environment, EvaluatedParameters)
{
	x_trigger(Environment)
}

