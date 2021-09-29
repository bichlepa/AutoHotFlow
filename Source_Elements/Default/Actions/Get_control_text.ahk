;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Control_Text")

;Element type of the element
Element_getElementType_Action_Get_Control_Text()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_Control_Text()
{
	return x_lang("Get_Control_Text")
}

;Category of the element
Element_getCategory_Action_Get_Control_Text()
{
	return x_lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Control_Text()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Control_Text()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Get_Control_Text()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Control_Text()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Control_Text(Environment)
{
	parametersToEdit:=Object()

	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "ControlText", content: "VariableName"})
	
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit, {withControl: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Control_Text(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Get_Control_Text") ": " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Control_Text(Environment, ElementParameters, staticValues)
{	
	windowFunctions_CheckSettings(ElementParameters)
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Control_Text(Environment, ElementParameters)
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

	; get window and control ID
	result := windowFunctions_getWindowAndControlID(EvaluatedWindowParameters)
	if (result.exception)
	{
		x_finish(Environment, "exception", result.exception)
		return
	}
	
	; check whether we found the control
	if (not result.controlID)
	{
		if (EvaluatedParameters.IdentifyControlBy = "ID")
		{
			x_finish(Environment, "exception", x_lang("Error! Seeked control does not exist")) 
			return
		}
		else if (not result.windowID)
		{
			x_finish(Environment, "exception", x_lang("Error! Seeked window does not exist")) 
			return
		}
		Else
		{
			x_finish(Environment, "exception", x_lang("Error! Seeked control does not exist in the specified window")) 
			return
		}
	}

	; get control text
	ControlGetText, controlText,, % "ahk_id " result.controlID
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, controlText)

	; set window ID and control ID as thread variables
	if (result.windowID) ; only if available
		x_SetVariable(Environment, "A_WindowID", result.windowID, "Thread")
	x_SetVariable(Environment, "A_ControlID", result.controlID, "Thread")
	
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Control_Text(Environment, ElementParameters)
{
	
}
