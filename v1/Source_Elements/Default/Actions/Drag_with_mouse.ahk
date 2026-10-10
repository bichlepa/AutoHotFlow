
;Name of the element
Element_getName_Action_Drag_With_Mouse()
{
	return x_lang("Drag_With_Mouse")
}

;Category of the element
Element_getCategory_Action_Drag_With_Mouse()
{
	return x_lang("User_simulation")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Drag_With_Mouse()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Drag_With_Mouse()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Drag_With_Mouse()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Drag_With_Mouse(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Which button")})
	parametersToEdit.push({type: "DropDown", id: "Button", default: "Left", result: "enum", choices: [x_lang("Left button"), x_lang("Right button"), x_lang("Middle Button"), x_lang("4th mouse button (back)"), x_lang("5th mouse button (forward)")], enum: ["Left", "Right", "Middle", "X1", "X2"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Mouse position")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: "Screen", result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position"), x_lang("Relative to current mouse position")], enum: ["Screen", "Window", "Client", "Relative"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Start coordinates") " " x_lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["XposFrom", "YposFrom"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTrackerFrom", goto: "Action_Drag_With_Mouse_MouseTracker_From", label: x_lang("Get coordinates")})
	
	parametersToEdit.push({type: "Label", label: x_lang("End coordinates") " " x_lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [100, 200], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTrackerTo", goto: "Action_Drag_With_Mouse_MouseTracker_To", label: x_lang("Get coordinates")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, result: "enum", choices: [x_lang("Input mode"), x_lang("Event mode"), x_lang("Play mode")], enum: ["Input", "Event", "Play"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Mouse movement speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Delay in ms")})
	parametersToEdit.push({type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true})
	
	return parametersToEdit
}

; button "Get coordinates" callback of first position. Opens the mouse tracker assistant
Action_Drag_With_Mouse_MouseTracker_From()
{
	x_assistant_MouseTracker({ImportMousePos: "Yes", CoordMode: "CoordMode", xpos: "XposFrom", ypos: "YposFrom"})
}
; button "Get coordinates" callback of second position. Opens the mouse tracker assistant
Action_Drag_With_Mouse_MouseTracker_To()
{
	x_assistant_MouseTracker({ImportMousePos: "Yes", CoordMode: "CoordMode", xpos: "xpos", ypos: "ypos"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Drag_With_Mouse(Environment, ElementParameters)
{
	switch (ElementParameters.Button)
	{
		case "Left":
		buttonText := x_lang("Left button")
		case "Right":
		buttonText := x_lang("Right button")
		case "Middle":
		buttonText := x_lang("Middle button")
		case "X1":
		buttonText := x_lang("4th mouse button (back)")
		case "X2":
		buttonText := x_lang("5th mouse button (forward)")
	}
	
	changePositionText := " - " x_lang("From '%1%' to '%2%'", ElementParameters.XposFrom "/"  ElementParameters.YposFrom, ElementParameters.Xpos "/"  ElementParameters.YposFrom)
	
	return x_lang("Drag_With_Mouse") " - " buttonText changePositionText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Drag_With_Mouse(Environment, ElementParameters, staticValues)
{	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Drag_With_Mouse(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check whether we got numbers
	Xpos := EvaluatedParameters.Xpos
	Ypos := EvaluatedParameters.Ypos
	XposFrom := EvaluatedParameters.XposFrom
	YposFrom := EvaluatedParameters.YposFrom
	Speed := EvaluatedParameters.Speed
	delay := EvaluatedParameters.delay
	if Xpos is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Second X position"))) 
		return
	}
	if Ypos is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Second Y position"))) 
		return
	}
	if XposFrom is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("First X position"))) 
		return
	}
	if YposFrom is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("First Y position"))) 
		return
	}
	if Speed is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Speed"))) 
		return
	
	}
	if delay is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Delay"))) 
		return
	}
	
	; set mouse delay
	if (EvaluatedParameters.SendMode = "play")
		SetMouseDelay, % delay, play
	else if (EvaluatedParameters.SendMode = "Event" or EvaluatedParameters.SendMode = "Input")
		SetMouseDelay, % delay
		
	; set send mode
	SendMode, % EvaluatedParameters.SendMode
	
	;set values for mouse click call depending on selected coordMode
	if (EvaluatedParameters.CoordMode = "relative")
	{
		CoordModeValue := ""
		relativeValue := "R"
	}
	Else
	{
		CoordModeValue := EvaluatedParameters.CoordMode
		relativeValue := ""
	}

	; set coord mode
	CoordMode, Mouse, %CoordModeValue%
	
	; drag mouse now
	MouseClickDrag, % EvaluatedParameters.Button, % XposFrom, % YposFrom, % Xpos, % Ypos, % speed, % relativeValue
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Drag_With_Mouse(Environment, ElementParameters)
{
	
}


