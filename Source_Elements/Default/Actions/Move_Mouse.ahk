;Always add this element class name to the global list
x_RegisterElementClass("Action_Move_Mouse")

;Element type of the element
Element_getElementType_Action_Move_Mouse()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Move_Mouse()
{
	return x_lang("Move_Mouse")
}

;Category of the element
Element_getCategory_Action_Move_Mouse()
{
	return x_lang("User_simulation")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Move_Mouse()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Move_Mouse()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Move_Mouse()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Move_Mouse()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Move_Mouse(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Mouse position")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position"), x_lang("Relative to current mouse position")], enum: ["Screen", "Window", "Client", "Relative"]})
	parametersToEdit.push({type: "Label", label: x_lang("Coordinates") x_lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionMove_MouseMouseTracker", label: x_lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, result: "enum", choices: [x_lang("Input mode"), x_lang("Event mode"), x_lang("Play mode")], enum: ["Input", "Event", "Play"]})
	parametersToEdit.push({type: "Label", label: x_lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	parametersToEdit.push({type: "Label", label: x_lang("Delay in ms")})
	parametersToEdit.push({type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true})
	
	
	return parametersToEdit
}

ActionMove_MouseMouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"xpos",ypos:"ypos"})
}
;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Move_Mouse(Environment, ElementParameters)
{
	return x_lang("Move_Mouse") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Move_Mouse(Environment, ElementParameters)
{	
	
	if (ElementParameters.SendMode = "input")
	{
		x_Par_Disable("speed")
	}
	else
	{
		x_Par_Enable("speed")
	}

}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Move_Mouse(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	;Parameter evaluation and check

	CoordModeValue := EvaluatedParameters.CoordMode
	SendModeValue := EvaluatedParameters.SendMode

	delay:=EvaluatedParameters.delay

	speed:=EvaluatedParameters.speed
	CoordModeValue := EvaluatedParameters.CoordMode
	Xpos:=EvaluatedParameters.Xpos
	Ypos:=EvaluatedParameters.Ypos
	
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
	
	if (CoordModeValue = "relative")
	{
		CoordModeValue := ""
		relativeValue:="R"
	}
		
	;Action
	SendMode, %SendModeValue%
	if (SendModeValue = "play")
		SetMouseDelay,%delay%, play
	else
		SetMouseDelay,%delay%
	
	
	CoordMode, Mouse, %CoordModeValue%
	MouseMove,% Xpos,% Ypos,% speed,%relativeValue%
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Move_Mouse(Environment, ElementParameters)
{
	
}



