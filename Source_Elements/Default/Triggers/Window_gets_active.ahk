;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Window_Gets_Active")

;Element type of the element
Element_getElementType_Trigger_Window_Gets_Active()
{
	return "trigger"
}

;Name of the element
Element_getName_Trigger_Window_Gets_Active()
{
	return x_lang("Window_Gets_Active")
}

;Category of the element
Element_getCategory_Trigger_Window_Gets_Active()
{
	return x_lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Window_Gets_Active()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Window_Gets_Active()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Trigger_Window_Gets_Active()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Window_Gets_Active()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Window_Gets_Active(Environment)
{
	
	parametersToEdit := Object()
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "NotTriggerOnEnable", default: 1, label: x_lang("Do not trigger if a matching window is active when enabling the trigger")})
	parametersToEdit.push({type: "Label", label: x_lang("Check interval (ms)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "interval", content: "Number", default: 500, WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Window_Gets_Active") ": " nameString
	
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Window_Gets_Active(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the trigger is activated
Element_enable_Trigger_Window_Gets_Active(Environment, ElementParameters)
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
	
	; We will set a timer which regularely checks the active window.
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Window_Gets_Active_TimerLabel", EvaluatedParameters, EvaluatedWindowParameters, [])
	x_SetTriggerValue(Environment, "functionObject", functionObject)
	
	; make the first call immediately
	%functionObject%(true)

	; enable the timer
	SetTimer, % functionObject, % EvaluatedParameters.interval

	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Window_Gets_Active(Environment, ElementParameters, TriggerData)
{
	; set the a_windowID variable
	x_SetVariable(Environment, "a_WindowID", TriggerData.windowID, "Thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal")
}

; function which will be regularey called
Trigger_Window_Gets_Active_TimerLabel(Environment, EvaluatedParameters, EvaluatedWindowParameters, staticData, fistCall = false)
{
	; set some properties before calling WinActive()
	SetTitleMatchMode, % EvaluatedWindowParameters.titlematchmode
	DetectHiddenText, % EvaluatedWindowParameters.findhiddentext
	DetectHiddenWindows, % EvaluatedWindowParameters.findhiddenwindow
	
	if (fistCall)
	{
		; check parameter NotTriggerOnEnable on first call
		if (EvaluatedParameters.NotTriggerOnEnable)
		{
			; if this parameter is set, we need to skip the trigger if the window is already active
			staticData.currentWindowID := WinActive(EvaluatedWindowParameters.winstring, EvaluatedWindowParameters.WinText, EvaluatedWindowParameters.ExcludeTitle, EvaluatedWindowParameters.ExcludeText)
		}
	}

	; call WinActive(). it will return the window ID if the window exists
	windowID := WinActive(EvaluatedWindowParameters.winstring, EvaluatedWindowParameters.WinText, EvaluatedWindowParameters.ExcludeTitle, EvaluatedWindowParameters.ExcludeText)

	; compare the windowID with the last found window 
	if (windowID != staticData.currentWindowID)
	{
		; the result has changed. Save the changed value.
		staticData.currentWindowID := windowID

		if (windowID)
		{
			; if we are here, a window was found that maches the criteria.
			; On last call either active window did not match or an other window was active

			; trigger and pass the windowID, so we can set the a_windowID variable later
			x_trigger(Environment, {windowID: windowID})
		}
	}
}