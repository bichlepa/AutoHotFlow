;Always add this element class name to the global list
x_RegisterElementClass("Action_Close_Window")

;Element type of the element
Element_getElementType_Action_Close_Window()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Close_Window()
{
	return x_lang("Close_Window")
}

;Category of the element
Element_getCategory_Action_Close_Window()
{
	return x_lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Close_Window()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Close_Window()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Close_Window()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Close_Window()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Close_Window(Environment)
{
	parametersToEdit:=Object()

	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "WinCloseMethod", default: 1, result: "enum", choices: [x_lang("Close"), x_lang("Kill")], enum: ["close", "kill"]})
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Close_Window(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)

	return x_lang("Close_Window") ": " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Close_Window(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Close_Window(Environment, ElementParameters)
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
		; window does not exist
		x_finish(Environment, "exception", x_lang("Error! Seeked window does not exist")) 
		return
	}
	
	; save the window ID as thread variable
	x_SetVariable(Environment, "A_WindowID", windowID,"Thread")

	; activate the window
	if (EvaluatedParameters.WinCloseMethod = "close")
	{
		WinClose, ahk_id %windowID%
	}
	else if (EvaluatedParameters.WinCloseMethod = "kill")
	{
		WinKill, ahk_id %windowID%
	}

	; finish
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Close_Window(Environment, ElementParameters)
{
	
}
