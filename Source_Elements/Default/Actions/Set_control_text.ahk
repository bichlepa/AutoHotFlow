﻿
;Name of the element
Element_getName_Action_Set_control_text()
{
	return x_lang("Set_control_text")
}

;Category of the element
Element_getCategory_Action_Set_control_text()
{
	return x_lang("Window")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_control_text()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Set_control_text()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_control_text()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_control_text(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Text to set")})
	parametersToEdit.push({type: "Edit", id: "Text", content: "String"})
	
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit, {withControl: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_control_text(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Set_control_text") ": " ElementParameters.Text " - " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_control_text(Environment, ElementParameters, staticValues)
{	
	windowFunctions_CheckSettings(ElementParameters)
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_control_text(Environment, ElementParameters)
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
	
	; set control text
	ControlSetText,,%  EvaluatedParameters.text, % "ahk_id " result.controlID
	
	; set window ID and control ID as thread variables
	if (result.windowID) ; only if available
		x_SetVariable(Environment, "A_WindowID", result.windowID, "Thread")
	x_SetVariable(Environment, "A_ControlID", result.controlID, "Thread")
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_control_text(Environment, ElementParameters)
{
}
