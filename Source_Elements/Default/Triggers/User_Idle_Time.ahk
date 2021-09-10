;Always add this element class name to the global list
x_RegisterElementClass("Trigger_User_Idle_Time")

;Element type of the element
Element_getElementType_Trigger_User_Idle_Time()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_User_Idle_Time()
{
	return x_lang("User_Idle_Time")
}

;Category of the element
Element_getCategory_Trigger_User_Idle_Time()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_User_Idle_Time()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_User_Idle_Time()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Trigger_User_Idle_Time()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_User_Idle_Time()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_User_Idle_Time(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Period of time")})
	parametersToEdit.push({type: "edit", id: "Interval", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: "Seconds", result: "enum", choices: [x_lang("MilliSeconds"), x_lang("Seconds"), x_lang("Minutes"), x_lang("Hours")], enum: ["MilliSeconds", "Seconds", "Minutes", "Hours"]})
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: "TimeIdle", result: "enum", choices: [x_lang("Method: %1%", x_lang("Default")), x_lang("Method: %1%", x_lang("Physical"))], enum: ["TimeIdle", "TimeIdlePhysical"]})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_User_Idle_Time(Environment, ElementParameters)
{
	switch (ElementParameters.Unit)
	{
	case "Milliseconds":
		duration := ElementParameters.Interval " " x_lang("ms #Milliseconds")
	case "Seconds":
		duration := ElementParameters.Interval " " x_lang("s #Seconds")
	case "Minutes":
		duration := ElementParameters.Interval " " x_lang("m #Minutes")
	}
	return x_lang("User_Idle_Time") " - " duration
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_User_Idle_Time(Environment, ElementParameters, staticValues)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_User_Idle_Time(Environment, ElementParameters)
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
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "interval", Interval)) 
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
	case "Hours":
		Interval *= 1000 * 60 * 60
	default:
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "Unit", EvaluatedParameters.Unit)) 
		return
	}

	; save the calculated interval
	EvaluatedParameters.calculatedInterval := Interval

	; check method
	switch (EvaluatedParameters.method)
	{
	case "TimeIdle":
	case "TimeIdlePhysical":
	default:
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "method", EvaluatedParameters.method)) 
		return
	}

	; We will set a timer which regularely triggers.
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_User_Idle_Time_Trigger", EvaluatedParameters)
	x_SetTriggerValue(environment, "functionObject", functionObject)
	SetTimer, % functionObject, -1
	
	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_User_Idle_Time(Environment, ElementParameters, TriggerData)
{

}

;Called when the trigger should be disabled.
Element_disable_Trigger_User_Idle_Time(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal")
}


;Function which checks the idle time and triggers the flow
Trigger_User_Idle_Time_Trigger(environment, EvaluatedParameters)
{
	; we will need the function object, so we can update the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	
	; get current idle time
	switch (EvaluatedParameters.method)
	{
	case "TimeIdle":
		userIdleTime := A_TimeIdle
	case "TimeIdlePhysical":
		userIdleTime := A_TimeIdlePhysical
	default:
		x_log("e0", "Method for getting the user idle time is invlaid: " EvaluatedParameters.method)
		return
	}

	; calculate the remaining time until we have to trigger
	remainingTime := EvaluatedParameters.calculatedInterval - userIdleTime
	
	; check current state
	if (EvaluatedParameters.currentlyUserIsIdle)
	{
		; we are in state after we triggered and we are waiting until the user is not idle anymore
		if (remainingTime > 0)
		{
			; user is not idle anymore
			EvaluatedParameters.currentlyUserIsIdle := false

			; check again after the remaining time
			SetTimer, % functionObject, % - remainingTime
		}
		else
		{
			; user is still idle
			; check again after half of the timeout time
			SetTimer, % functionObject, % - EvaluatedParameters.calculatedInterval / 2
		}
	}
	else
	{
		; we are in state where we are waiting until the idle time reaches the timeout
		if (remainingTime > 0)
		{
			; user is still not idle
			; check again after the remaining time
			SetTimer, % functionObject, % - remainingTime
		}
		else
		{
			; user just became idle
			EvaluatedParameters.currentlyUserIsIdle := true

			; trigger
			x_trigger(Environment)

			; check again after half of the timeout time
			SetTimer, % functionObject, % - EvaluatedParameters.calculatedInterval / 2
		}
	}
}
