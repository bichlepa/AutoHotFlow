;Name of the element
Element_getName_Trigger_Window_Opens()
{
	return x_lang("Window_Opens")
}

;Category of the element
Element_getCategory_Trigger_Window_Opens()
{
	return x_lang("Window")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Window_Opens()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Trigger_Window_Opens()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Window_Opens()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Window_Opens(Environment)
{
	
	parametersToEdit := Object()
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "NotTriggerOnEnable", default: 1, label: x_lang("Do not trigger if a matching window exists when enabling the trigger")})
	parametersToEdit.push({type: "Label", label: x_lang("Check interval (ms)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "interval", content: "Number", default: 500, WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Window_Opens(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Window_Opens") ": " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Window_Opens(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the trigger is activated
Element_enable_Trigger_Window_Opens(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; evaluate window parameters
	EvaluatedWindowParameters := windowFunctions_evaluateWindowParameters(EvaluatedParameters)
	if (EvaluatedWindowParameters.exception)
	{
		x_finish(Environment, "exception", EvaluatedWindowParameters.exception)
		return
	}

	; check interval
	if (not (EvaluatedParameters.interval > 0))
	{
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "interval", EvaluatedParameters.interval)) 
		return
	}

	; if there is no matching window on first call of the function object, we will not trigger
	EvaluatedParameters.firstCall := true

	; We will set a timer which regularely checks the active window.
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Window_Opens_TimerLabel", EvaluatedParameters, EvaluatedWindowParameters, [])
	x_SetTriggerValue(Environment, "functionObject", functionObject)
	
	; make the first call immediately
	; the passed value is the last parameter of the function Trigger_Window_Opens_TimerLabel
	%functionObject%(true)

	; enable the timer
	SetTimer, % functionObject, % EvaluatedParameters.interval

	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Window_Opens(Environment, ElementParameters, TriggerData)
{
	x_SetVariable(Environment, "a_WindowID", TriggerData.windowID, "Thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Window_Opens(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal")
}

; function which will be regularey called
Trigger_Window_Opens_TimerLabel(Environment, EvaluatedParameters, EvaluatedWindowParameters, staticData, fistCall = false)
{
	; set some properties before calling winGet
	SetTitleMatchMode, % EvaluatedWindowParameters.titlematchmode
	DetectHiddenText, % EvaluatedWindowParameters.findhiddentext
	DetectHiddenWindows, % EvaluatedWindowParameters.findhiddenwindow

	; firstCall is true if the function object was called with a parameter true
	if (fistCall)
	{
		; check parameter NotTriggerOnEnable on first call
		if (EvaluatedParameters.NotTriggerOnEnable)
		{
			; on first call, we need to skip the trigger
			winget, winList, list, % EvaluatedWindowParameters.winstring, % EvaluatedWindowParameters.WinText, % EvaluatedWindowParameters.ExcludeTitle, % EvaluatedWindowParameters.ExcludeText
			
			; convert the pseudo-array to a real array and save current window list
			staticData.currentWinList := []
			loop % winList
			{
				oneWindowID := winList%a_index%
				staticData.currentWinList[oneWindowID] := true
			}
		}
	}

	; call winGet. it will return all matching window IDs
	winget, winList, list, % EvaluatedWindowParameters.winstring, % EvaluatedWindowParameters.WinText, % EvaluatedWindowParameters.ExcludeTitle, % EvaluatedWindowParameters.ExcludeText

	; convert the pseudo-array to a real array
	currentWinList := []
	loop % winList
	{
		oneWindowID := winList%a_index%
		currentWinList[oneWindowID] := true
	}

	; check whether some new elements appeared
	for oneWindowID in currentWinList
	{
		if (not staticData.currentWinList.hasKey(oneWindowID))
		{
			; a new window found. Call the trigger
			x_trigger(Environment, {windowID: oneWindowID})
		}
	}

	; save current window list
	staticData.currentWinList := currentWinList
}