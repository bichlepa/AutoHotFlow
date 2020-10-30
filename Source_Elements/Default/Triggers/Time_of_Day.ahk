;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Time_Of_Day")

;Element type of the element
Element_getElementType_Trigger_Time_Of_Day()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Time_Of_Day()
{
	return lang("Time_Of_Day")
}

;Category of the element
Element_getCategory_Trigger_Time_Of_Day()
{
	return lang("Time")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Time_Of_Day()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Time_Of_Day()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Time_Of_Day()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Time_Of_Day()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Time_Of_Day(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Weekdays")})
	parametersToEdit.push({type: "Weekdays", id: "WeekDays", default: "1234567", WarnIfEmpty: "true"})
	parametersToEdit.push({type: "Label", label: lang("Time of day")})
	parametersToEdit.push({type: "DateAndTime", id: "Time", default: a_now, format: "Time"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Time_Of_Day(Environment, ElementParameters)
{
	return lang("Time_Of_Day") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Time_Of_Day(Environment, ElementParameters)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_Time_Of_Day(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; calculate next trigger time
	remainingSeconds := Trigger_Time_Of_Day_Trigger_FindNextTimestamp(EvaluatedParameters.WeekDays, EvaluatedParameters.Time)
	if (remainingSeconds = "")
	{
		x_enabled(Environment, "exception", lang("Can't calculate next trigger time"))
		x_log(Environment, "WeekDays: " EvaluatedParameters.WeekDays ", Time: " EvaluatedParameters.Time, 1)
		return
	}

	; We will set a timer which triggers on the next trigger time.
	functionObject := x_NewFunctionObject(environment, "Trigger_Time_Of_Day_Trigger", EvaluatedParameters)
	x_SetTriggerValue(environment, "functionObject", functionObject)
	SetTimer, % functionObject, % - remainingSeconds * 1000
	
	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Time_Of_Day(Environment, ElementParameters)
{

}

;Called when the trigger should be disabled.
Element_disable_Trigger_Time_Of_Day(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal", lang("Stopped."))
}



;Find the next timestamp, when the trigger should start
Trigger_Time_Of_Day_Trigger_FindNextTimestamp(WeekDays, TimeOfDay)
{
	; create an AHK timestamp with todays date and the set time of day
	FormatTime, TimeWithoutDate, % TimeOfDay, HHmmss
	NewTime := A_YYYY . A_MM . A_DD . TimeWithoutDate ;Create a new time and date

	loop 8 ;Go through all days of week
	{
		; add one day on each iteration (not at first iteration)
		if a_index != 1
			EnvAdd, NewTime, 1, days
		
		; calculate remaining time
		remainingSeconds := NewTime
		EnvSub, remainingSeconds, a_now, seconds

		;Catch if the time is already passed. This may occure in the first loop iteration
		if (remainingSeconds > 0)
		{
			; get the weekday number of the new day
			FormatTime, oneDayOfWeek, %NewTime%, WDay

			; check whether the weekday is checked
			IfInString, WeekDays, % oneDayOfWeek
			{
				; weekday is checked. Return this time
				return remainingSeconds
			}
		}
	}
}

;Function which triggers the flow
Trigger_Time_Of_Day_Trigger(environment, EvaluatedParameters)
{
	; calculate the next trigger time
	remainingSeconds := Trigger_Time_Of_Day_Trigger_FindNextTimestamp(EvaluatedParameters.WeekDays, EvaluatedParameters.Time)
	if (remainingSeconds = "")
	{
		x_log(Environment, lang("Can't calculate next trigger time"), 0) 
		x_log(Environment, "WeekDays: " EvaluatedParameters.WeekDays ", Time: " EvaluatedParameters.Time, 1)
		return
	}
	
	; update the timer to the next trigger time
	functionObject := x_GetTriggerValue(environment, "functionObject")
	SetTimer, % functionObject, % - remainingSeconds * 1000
	
	; trigger the flow
	x_trigger(Environment)
}
