
;Name of the element
Element_getName_Action_Click()
{
	return x_lang("Click")
}

;Category of the element
Element_getCategory_Action_Click()
{
	return x_lang("User_simulation")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Click()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Click()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Click()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Click(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Which button")})
	parametersToEdit.push({type: "DropDown", id: "Button", default: "Left", result: "enum", choices: [x_lang("Left button"), x_lang("Right button"), x_lang("Middle Button"), x_lang("Wheel up"), x_lang("Wheel down"), x_lang("Wheel left"), x_lang("Wheel right"), x_lang("4th mouse button (back)"), x_lang("5th mouse button (forward)")], enum: ["Left", "Right", "Middle", "WheelUp", "WheelDown", "WheelLeft", "WheelRight", "X1", "X2"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Click count")})
	parametersToEdit.push({type: "Edit", id: "ClickCount", default: 1, content: "Expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Event")})
	parametersToEdit.push({type: "Radio", id: "DownUp", default: "Click", result: "enum", choices: [x_lang("Click (Down and up)"), x_lang("Hold down"), x_lang("Release only")], enum: ["Click", "D", "U"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Mouse position")})
	parametersToEdit.push({type: "Checkbox", id: "changePosition", default: 0, label: x_lang("Move mouse before clicking")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: "Screen", result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position"), x_lang("Relative to current mouse position")], enum: ["Screen", "Window", "Client", "Relative"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Coordinates") x_lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionClickMouseTracker", label: x_lang("Get coordinates")})

	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: "Input", result: "enum", choices: [x_lang("Input mode"), x_lang("Event mode"), x_lang("Play mode")], enum: ["Input", "Event", "Play"]})

	parametersToEdit.push({type: "Label", label: x_lang("Mouse movement speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})

	parametersToEdit.push({type: "Label", label: x_lang("Delay in ms")})
	parametersToEdit.push({type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true})
	
	return parametersToEdit
}

; button "Get coordinates" callback. Opens the mouse tracker assistant
ActionClickMouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos: "Yes", CoordMode: "CoordMode", xpos: "xpos", ypos: "ypos"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Click(Environment, ElementParameters)
{
	switch (ElementParameters.Button)
	{
		case "Left":
		buttonText := x_lang("Left button")
		case "Right":
		buttonText := x_lang("Right button")
		case "Middle":
		buttonText := x_lang("Middle button")
		case "WheelUp":
		buttonText := x_lang("Wheel up")
		case "WheelDown":
		buttonText := x_lang("Wheel down")
		case "WheelLeft":
		buttonText := x_lang("Wheel left")
		case "WheelRight":
		buttonText := x_lang("Wheel right")
		case "X1":
		buttonText := x_lang("4th mouse button (back)")
		case "X2":
		buttonText := x_lang("5th mouse button (forward)")
	}
	if (ElementParameters.ClickCount != 1)
	{
		clickCountText := " - " x_lang("%1% times", ElementParameters.ClickCount)
	}
	if (ElementParameters.DownUp != 1)
	{
		switch (ElementParameters.DownUp)
		{
			case "Click":
			DownUpText := " - " x_lang("Click")
			case "D":
			DownUpText := " - " x_lang("Hold down")
			case "U":
			DownUpText := " - " x_lang("Release")
		}
	}
	if (ElementParameters.changePosition)
	{
		changePositionText := " - " x_lang("Move mouse")
	}
	return x_lang("Click") " - " buttonText DownUpText clickCountText changePositionText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Click(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.changePosition = 1)
	{
		x_Par_Enable("Xpos")
		x_Par_Enable("Ypos")
		x_Par_Enable("CoordMode")
		x_Par_Enable("speed")
	}
	else
	{
		x_Par_Disable("Xpos")
		x_Par_Disable("Ypos")
		x_Par_Disable("CoordMode")
		x_Par_Disable("speed")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Click(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["Xpos", "Ypos", "speed", "CoordMode"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; prepare DownUp value
	switch (EvaluatedParameters.DownUp)
	{
		case "click":
		updownValue := ""
		case "D":
		updownValue := "D"
		case "U":
		updownValue := "U"
	}
	
	; set send mode
	SendMode, % EvaluatedParameters.SendMode

	; check whether we got a number for delay
	delay := EvaluatedParameters.delay
	if delay is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Delay"))) 
		return
	}

	; set mouse delay
	if (EvaluatedParameters.SendMode = "play")
		SetMouseDelay, % delay, play
	else if (EvaluatedParameters.SendMode = "Event")
		SetMouseDelay, % delay
	
	if (EvaluatedParameters.changePosition)
	{
		; we need to change the position.

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Xpos", "Ypos", "CoordMode", "speed", "Delay"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		; check xpos and ypos values
		Xpos := EvaluatedParameters.Xpos
		Ypos := EvaluatedParameters.Ypos
		Speed := EvaluatedParameters.Speed
		if Xpos is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("X position"))) 
			return
		}
		if Ypos is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("Y position"))) 
			return
		}
		if Speed is not number
		{
			x_finish(Environment, "exception", x_lang("%1% is not a number.", x_lang("Speed"))) 
			return
		}
		
		; set values for mouse click call depending on selected coordMode
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

		; click with mouse movement
		MouseClick, % EvaluatedParameters.Button, % Xpos, % Ypos, % EvaluatedParameters.ClickCount, % speed, % updownValue, %relativeValue%
	}
	else
	{
		; we do not need to change the position. Click without mouse movement
		MouseClick, % EvaluatedParameters.Button,,, % EvaluatedParameters.ClickCount,, % updownValue
	}

	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Click(Environment, ElementParameters)
{
	
}



