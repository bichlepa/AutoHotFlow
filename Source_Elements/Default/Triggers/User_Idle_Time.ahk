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
	return lang("User_Idle_Time")
}

;Category of the element
Element_getCategory_Trigger_User_Idle_Time()
{
	return lang("User_interaction")
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

;Icon path which will be shown in the background of the element
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
	
	parametersToEdit.push({type: "Label", label: lang("Period of time")})
	parametersToEdit.push({type: "edit", id: "Intervall_S", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [lang("Seconds"), lang("Minutes"), lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]})
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: 1, result: "enum", choices: [lang("Method %1%", 1), lang("Method %1%", 2)], enum: ["TimeIdle", "TimeIdlePhysical"]})

	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_User_Idle_Time(Environment, ElementParameters)
{
	return lang("User_Idle_Time") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_User_Idle_Time(Environment, ElementParameters)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_User_Idle_Time(Environment, ElementParameters)
{
	
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (ElementParameters.Unit="Seconds") ;Milliseconds
		tempDuration:=ElementParameters.Intervall_S * 1000
	else if (ElementParameters.Unit="Minutes") ;Seconds
		tempDuration:=ElementParameters.Intervall_S * 1000 * 60
	else if (ElementParameters.Unit="Hours") ;minutes
		tempDuration:=ElementParameters.Intervall_S * 1000 * 60 * 60
	
	if (tempDuration < 100)
	{
		x_log("e1", "Specified user idle time must be at least 100ms. Current value: " tempDuration " ms")
		return
	}
	functionObject:= x_NewExecutionFunctionObject(environment, "Trigger_User_Idle_Time_Trigger", EvaluatedParameters, tempDuration)
	x_SetExecutionValue(environment, "functionObject", functionObject)
	SetTimer, % functionObject, -1
	
	x_enabled(Environment, "normal")
}

;Function which triggers the flow
Trigger_User_Idle_Time_Trigger(environment, EvaluatedParameters, par_Duration)
{
	userIsAlreadyIdle := x_GetExecutionValue(environment, "UserIsIdle")
	functionObject := x_GetExecutionValue(environment, "functionObject")
	
	if (EvaluatedParameters.method = "TimeIdle")
		userIdleTime:=A_TimeIdle
	else if (EvaluatedParameters.method = "TimeIdlePhysical")
		userIdleTime:=A_TimeIdlePhysical
	else
	{
		x_log("e1", "Method for getting the user idle time is not specified")
		return
	}
	
	remainingTime:=par_Duration - userIdleTime
	
	if (userIsAlreadyIdle)
	{
		if (remainingTime > 0)
		{
			x_SetExecutionValue(environment, "UserIsIdle", false)
			SetTimer,% functionObject, % - remainingTime
		}
		else
		{
			SetTimer,% functionObject, % - par_Duration / 2
		}
	}
	else
	{
		if (remainingTime <= 0)
		{
			x_SetExecutionValue(environment, "UserIsIdle", true)
			x_trigger(Environment)
			SetTimer,% functionObject, % - par_Duration / 2
		}
		else
		{
			SetTimer,% functionObject, % - remainingTime
		}
	}
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_User_Idle_Time(Environment, ElementParameters)
{

}

;Called when the trigger should be disabled.
Element_disable_Trigger_User_Idle_Time(Environment, ElementParameters)
{
	functionObject := x_GetExecutionValue(environment, "functionObject")
	SetTimer, % functionObject, delete
	x_disabled(Environment, "normal")
}



