;Always add this element class name to the global list
AllElementClasses.push("Action_Click")

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

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Click()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Button"})
	parametersToEdit.push({id: "ClickCount"})
	parametersToEdit.push({id: "DownUp"})
	parametersToEdit.push({id: "changePosition"})
	parametersToEdit.push({id: "CoordMode"})
	parametersToEdit.push({id: "Xpos"})
	parametersToEdit.push({id: "Ypos"})
	parametersToEdit.push({id: "SendMode"})
	parametersToEdit.push({id: "speed"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Click(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Which button")})
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, choices: [lang("Left button"), lang("Right button"), lang("Middle Button"), lang("Wheel up"), lang("Wheel down"), lang("Wheel left"), lang("Wheel right"), lang("4th mouse button (back)"), lang("5th mouse button (forward)")], result: "number"})
	parametersToEdit.push({type: "Label", label: lang("Click count")})
	parametersToEdit.push({type: "Edit", id: "ClickCount", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Event")})
	parametersToEdit.push({type: "Radio", id: "DownUp", default: 1, choices: [lang("Click (Down and up)"), lang("Keep down"), lang("Release only")]})
	parametersToEdit.push({type: "Label", label: lang("Mouse position")})
	parametersToEdit.push({type: "Checkbox", id: "changePosition", default: 0, label: lang("Move mouse before clicking")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position"), lang("Relative to current mouse position")]})
	parametersToEdit.push({type: "Label", label: lang("Coordinates") lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionClickMouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, choices: [lang("Input mode"), lang("Event mode"), lang("Play mode")]})
	parametersToEdit.push({type: "Label", label: lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	
	
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
		
		if (ElementParameters.SendMode = 1)
		{
			x_Par_Enable("speed")
		}
		else
		{
		x_Par_Disable("speed")
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
	;Parameter evaluation and check
	changePosition := ElementParameters.changePosition

	DownUpIdx := ElementParameters.DownUp
	CoordModeIdx := ElementParameters.CoordMode
	SendModeIdx := ElementParameters.SendMode

	evRes := x_evaluateExpression(Environment,ElementParameters.ClickCount)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.ClickCount) "`n`n" evRes.error) 
		return
	}
	ClickCount:=evRes.result

	ButtonIdx := ElementParameters.Button

	speed:=ElementParameters.speed


	if ButtonIdx=1
		ButtonName=Left
	else if ButtonIdx=2
		ButtonName=Right
	else if ButtonIdx=3
		ButtonName=Middle
	else if ButtonIdx=4
		ButtonName=WheelUp
	else if ButtonIdx=5
		ButtonName=WheelDown
	else if ButtonIdx=6
		ButtonName=WheelLeft
	else if ButtonIdx=7
		ButtonName=WheelRight
	else if ButtonIdx=8
		ButtonName=X1
	else if ButtonIdx=9
		ButtonName=X2
	else
		x_finish(Environment, "exception", lang("Mouse button index invalid: '%1%'", ElementParameters.button)) 
	
	if changePosition
	{
		evRes := x_evaluateExpression(Environment,ElementParameters.Xpos)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Xpos) "`n`n" evRes.error) 
			return
		}
		Xpos:=evRes.result
		evRes := x_evaluateExpression(Environment,ElementParameters.Ypos)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Ypos) "`n`n" evRes.error) 
			return
		}
		Ypos:=evRes.result
		
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
		
		if CoordModeIdx=1
			CoordModeValue= Screen
		else if CoordModeIdx=2
			CoordModeValue= Window
		else if CoordModeIdx=3
			CoordModeValue= Client

		if CoordModeIdx=4
			relativeValue=R
	}

	if SendModeIdx=1
		SendmodeValue= Input
	else if SendModeIdx=2
		SendmodeValue= Event
	else if SendModeIdx=3
		SendmodeValue= Play
	else
		x_finish(Environment, "exception", lang("Send mode has invalid value: '%1%'", ElementParameters.button))
	
	if DownUpIdx=1
		updownValue=
	else if DownUpIdx=2
		updownValue=D
	else if DownUpIdx=3
		updownValue=U
	else
		x_finish(Environment, "exception", lang("Send mode has invalid value: '%1%'", ElementParameters.button))
	
	if CoordModeIdx=1
		CoordMode, Mouse, Screen
	else if CoordModeIdx=2
		CoordMode, Mouse, Window
	else if CoordModeIdx=3
		CoordMode, Mouse, Client
		
	;Action
	SendMode, %SendmodeValue%
	if changePosition=1
	{
		if not relativeValue
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





Action_Click_ButtonClick()
{
	x_assistant_MouseTracker({CoordMode: "CoordMode", Xpos: "Xpos", Ypos: "Ypos"})
}

