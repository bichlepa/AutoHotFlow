
;Name of the element
Element_getName_Action_Move_Window()
{
	return x_lang("Move_Window")
}

;Category of the element
Element_getCategory_Action_Move_Window()
{
	return x_lang("Window")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Move_Window()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Move_Window()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Move_Window()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Move_Window(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Event")})
	parametersToEdit.push({type: "Radio", id: "WinMoveEvent", default: 1, result: "enum", choices: [x_lang("Maximize"), x_lang("Minimize"), x_lang("Restore"), x_lang("Move")], enum: ["Maximize", "Minimize", "Restore", "Move"]})
	parametersToEdit.push({type: "Label", label: x_lang("Coordinates") " (x,y)", size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], content: "Number"})
	parametersToEdit.push({type: "Label", label: x_lang("Width and height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], content: "Number"})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "Action_Move_Window_ButtonGetWinPosAssistant", label: x_lang("Grab coordinates from existing window")})
	
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Move_Window(Environment, ElementParameters)
{
	; generate window identification name
	nameString := windowFunctions_generateWindowIdentificationName(ElementParameters)
	
	return x_lang("Move_Window") ": " nameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Move_Window(Environment, ElementParameters, staticValues)
{	
	x_Par_Enable("Xpos", ElementParameters.WinMoveEvent = "Move")
	x_Par_Enable("Ypos", ElementParameters.WinMoveEvent = "Move")
	x_Par_Enable("Width", ElementParameters.WinMoveEvent = "Move")
	x_Par_Enable("Height", ElementParameters.WinMoveEvent = "Move")
	x_Par_Enable("MouseTracker", ElementParameters.WinMoveEvent = "Move")
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Move_Window(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["Xpos", "Ypos", "Width", "Height"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.WinMoveEvent = "Move") ;Move window
	{
		; we want to move the window, so we need to evaluate some more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Xpos", "Ypos", "Width", "Height"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		Xpos := EvaluatedParameters.Xpos
		if Xpos is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Parameter '%1%' ('%2%')", "Xpos", Xpos))) 
			return
		}
		Ypos := EvaluatedParameters.Ypos
		if Ypos is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Parameter '%1%' ('%2%')", "Ypos", Ypos))) 
			return
		}
		Width := EvaluatedParameters.Width
		if Width is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Parameter '%1%' ('%2%')", "Width", Width))) 
			return
		}
		Height := EvaluatedParameters.Height
		if Height is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Parameter '%1%' ('%2%')", "Height", Height))) 
			return
		}
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

	if (windowID)
	{
		; window found. Perform an action on it
		x_SetVariable(Environment, "A_WindowID", windowID, "Thread")
		if (EvaluatedParameters.WinMoveEvent = "Maximize") ;Maximize
		{
			WinMaximize, ahk_id %windowID%
		}
		else if (EvaluatedParameters.WinMoveEvent = "Minimize") ;Minimize
		{
			WinMinimize, ahk_id %windowID%
		}
		else if (EvaluatedParameters.WinMoveEvent = "Restore") ;Restore
		{
			WinRestore, ahk_id %windowID%
		}
		else if (EvaluatedParameters.WinMoveEvent = "Move") ;Move
		{
			WinMove, ahk_id %windowID%,, % Xpos, % Ypos, % Width, % Height
		}
		
		x_finish(Environment, "normal")
		return
	}
	else
	{
		x_finish(Environment, "exception", x_lang("Error! Seeked window does not exist")) 
		return
	}
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Move_Window(Environment, ElementParameters)
{
	
}


; opens the assistant for getting window information
Action_Move_Window_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

; opens the assistant for getting coordinates
Action_Move_Window_ButtonGetWinPosAssistant()
{
	x_assistant_windowParameter({Xpos: "Xpos", Ypos: "Ypos", Width: "Width", Height: "Height"})
}
