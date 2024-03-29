﻿
;Name of the element
Element_getName_Condition_Window_Exists()
{
	return x_lang("Window_Exists")
}

;Category of the element
Element_getCategory_Condition_Window_Exists()
{
	return x_lang("Window")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Window_Exists()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Condition_Window_Exists()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Window_Exists()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Window_Exists(Environment)
{
	parametersToEdit := Object()
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Window_Exists(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Window_Exists") ": " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Window_Exists(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Window_Exists(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; evaluate window parameters
	EvaluatedWindowParameters := windowFunctions_evaluateWindowParameters(EvaluatedParameters)
	if (EvaluatedWindowParameters.exception)
	{
		x_finish(Environment, "exception", EvaluatedWindowParameters.exception)
		return
	}

	; get window ID
	windowID := windowFunctions_getWindowID(EvaluatedWindowParameters)
	if (windowID.exception)
	{
		x_finish(Environment, "exception", windowID.exception)
		return
	}
	
	if not windowID
	{
		; window does not exist. Finish
		x_finish(Environment, "no")
		return
	}
	
	; save the window ID as thread variable
	x_SetVariable(Environment, "A_WindowID", windowID, "Thread")

	; finish
	x_finish(Environment, "yes")
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Window_Exists(Environment, ElementParameters)
{
}
