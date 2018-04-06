;Always add this element class name to the global list
x_RegisterElementClass("Action_Click")

;Element type of the element
Element_getElementType_Action_Click()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Click()
{
	return lang("Click")
}

;Category of the element
Element_getCategory_Action_Click()
{
	return lang("User_simulation")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Click()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Click()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
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
	
	parametersToEdit.push({type: "Label", label: lang("Which button")})
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, result: "enum", choices: [lang("Left button"), lang("Right button"), lang("Middle Button"), lang("Wheel up"), lang("Wheel down"), lang("Wheel left"), lang("Wheel right"), lang("4th mouse button (back)"), lang("5th mouse button (forward)")], enum: ["Left", "Right", "Middle", "WheelUp", "WheelDown", "WheelLeft", "WheelRight", "X1", "X2"]})
	parametersToEdit.push({type: "Label", label: lang("Click count")})
	parametersToEdit.push({type: "Edit", id: "ClickCount", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Event")})
	parametersToEdit.push({type: "Radio", id: "DownUp", default: 1, result: "enum", choices: [lang("Click (Down and up)"), lang("Keep down"), lang("Release only")], enum: ["Click", "D", "U"]})
	parametersToEdit.push({type: "Label", label: lang("Mouse position")})
	parametersToEdit.push({type: "Checkbox", id: "changePosition", default: 0, label: lang("Move mouse before clicking")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position"), lang("Relative to current mouse position")], enum: ["Screen", "Window", "Client", "Relative"]})
	parametersToEdit.push({type: "Label", label: lang("Coordinates") lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionClickMouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, result: "enum", choices: [lang("Input mode"), lang("Event mode"), lang("Play mode")], enum: ["Input", "Event", "Play"]})
	parametersToEdit.push({type: "Label", label: lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Delay in ms")})
	parametersToEdit.push({type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true})
	
	
	return parametersToEdit
}

ActionClickMouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"xpos",ypos:"ypos"})
}
;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Click(Environment, ElementParameters)
{
	return lang("Click") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Click(Environment, ElementParameters)
{	
	if (ElementParameters.changePosition = 1)
	{
		x_Par_Enable("Xpos")
		x_Par_Enable("Ypos")
		x_Par_Enable("CoordMode")
		
		if (ElementParameters.SendMode = "input")
		{
			x_Par_Disable("speed")
		}
		else
		{
			x_Par_Enable("speed")
		}
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
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["Xpos", "Ypos", "speed", "CoordMode"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	;Parameter evaluation and check

	updownValue := EvaluatedParameters.DownUp
	SendModeValue := EvaluatedParameters.SendMode

	ClickCount:=EvaluatedParameters.ClickCount

	delay:=EvaluatedParameters.delay

	ButtonName := EvaluatedParameters.Button


	if (updownValue="click")
		updownValue=
	
	
	if (EvaluatedParameters.changePosition)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Xpos", "Ypos", "speed", "CoordMode"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		speed:=EvaluatedParameters.speed
		CoordModeValue := EvaluatedParameters.CoordMode
		Xpos:=EvaluatedParameters.Xpos
		Ypos:=EvaluatedParameters.Ypos
		
		if Xpos is not number
		{
			x_finish(Environment, "exception", lang("%1% is not a number.",lang("X position"))) 
			return
		}
		if Ypos is not number
		{
			x_finish(Environment, "exception", lang("%1% is not a number.",lang("Y position"))) 
			return
		}
		
		if (CoordModeValue = "relative")
		{
			CoordModeValue := ""
			relativeValue:="R"
		}
	}
		
	;Action
	SendMode, %SendModeValue%
	if (SendModeValue = "play")
		SetMouseDelay,%delay%, play
	else
		SetMouseDelay,%delay%
	
	if (EvaluatedParameters.changePosition)
	{
		CoordMode, Mouse, %CoordModeValue%
		MouseClick,%ButtonName%,% Xpos,% Ypos,% ClickCount,% speed,%updownValue%,%relativeValue%
	}
	else
	{
		MouseClick,%ButtonName%,,,% ClickCount,,%updownValue%
	}
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Click(Environment, ElementParameters)
{
	
}



