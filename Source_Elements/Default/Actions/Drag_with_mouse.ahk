;Always add this element class name to the global list
x_RegisterElementClass("Action_Drag_With_Mouse")

;Element type of the element
Element_getElementType_Action_Drag_With_Mouse()
{
	return "Action"
}

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

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Drag_With_Mouse()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Drag_With_Mouse()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
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
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, result: "enum", choices: [x_lang("Left button"), x_lang("Right button"), x_lang("Middle Button"), x_lang("Wheel up"), x_lang("Wheel down"), x_lang("Wheel left"), x_lang("Wheel right"), x_lang("4th mouse button (back)"), x_lang("5th mouse button (forward)")], enum: ["Left", "Right", "Middle", "WheelUp", "WheelDown", "WheelLeft", "WheelRight", "X1", "X2"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Mouse position")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position"), x_lang("Relative to current mouse position")], enum: ["Screen", "Window", "Client", "Relative"]})
	parametersToEdit.push({type: "Label", label: x_lang("Start coordinates") " " x_lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["XposFrom", "YposFrom"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTrackerFrom", goto: "Action_Drag_With_Mouse_MouseTracker_From", label: x_lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: x_lang("End coordinates") " " x_lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [100, 200], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTrackerTo", goto: "Action_Drag_With_Mouse_MouseTracker_To", label: x_lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, result: "enum", choices: [x_lang("Input mode"), x_lang("Event mode"), x_lang("Play mode")], enum: ["Input", "Event", "Play"]})
	parametersToEdit.push({type: "Label", label: x_lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	parametersToEdit.push({type: "Label", label: x_lang("Delay in ms")})
	parametersToEdit.push({type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true})
	
	
	return parametersToEdit
}

Action_Drag_With_Mouse_MouseTracker_From()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"XposFrom",ypos:"YposFrom"})
}
Action_Drag_With_Mouse_MouseTracker_To()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"xpos",ypos:"ypos"})
}
;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Drag_With_Mouse(Environment, ElementParameters)
{
	return x_lang("Drag_With_Mouse") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Drag_With_Mouse(Environment, ElementParameters, staticValues)
{	

	x_Par_Enable("Xpos")
	x_Par_Enable("Ypos")
	x_Par_Enable("CoordMode")
	
	if (ElementParameters.SendMode = "input")
	{
		x_Par_Disable("speed")
		x_Par_Disable("delay")
	}
	else
	{
		x_Par_Enable("speed")
		x_Par_Enable("delay")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Drag_With_Mouse(Environment, ElementParameters)
{
	;Parameter evaluation and check
	CoordModeValue := ElementParameters.CoordMode
	SendModeValue := ElementParameters.SendMode

	evRes := x_evaluateExpression(Environment,ElementParameters.delay)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.delay) "`n`n" evRes.error) 
		return
	}
	delay:=evRes.result
	
	ButtonName := ElementParameters.Button

	speed:=ElementParameters.speed

	if (updownValue="click")
		updownValue=
	
	if (CoordModeValue = "relative")
	{
		CoordModeValue := ""
		relativeValue:="R"
	}
	
	evRes := x_evaluateExpression(Environment,ElementParameters.Xpos)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.Xpos) "`n`n" evRes.error) 
		return
	}
	Xpos:=evRes.result
	
	evRes := x_evaluateExpression(Environment,ElementParameters.Ypos)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.Ypos) "`n`n" evRes.error) 
		return
	}
	Ypos:=evRes.result
	
	evRes := x_evaluateExpression(Environment,ElementParameters.XposFrom)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.XposFrom) "`n`n" evRes.error) 
		return
	}
	XposFrom:=evRes.result
	
	evRes := x_evaluateExpression(Environment,ElementParameters.YposFrom)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.YposFrom) "`n`n" evRes.error) 
		return
	}
	YposFrom:=evRes.result
	
	if Xpos is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("Second X position"))) 
		return
	}
	if Ypos is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("Second Y position"))) 
		return
	}
	if XposFrom is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("First X position"))) 
		return
	}
	if YposFrom is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("First Y position"))) 
		return
	}
	
		
	;Action
	SendMode, %SendModeValue%
	if (SendModeValue = "play")
	{
		SetMouseDelay,%delay%, play
	}
	else
		SetMouseDelay,%delay%
	
	if CoordModeValue
		CoordMode, Mouse, %CoordModeValue%
	
	MouseClickDrag,% ButtonName,% XposFrom,% YposFrom,% Xpos,% Ypos,% speed,% relativeValue
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Drag_With_Mouse(Environment, ElementParameters)
{
	
}


