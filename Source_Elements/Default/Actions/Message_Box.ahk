;Always add this element class name to the global list
x_RegisterElementClass("Action_Message_Box")

;Element type of the element
Element_getElementType_Action_Message_Box()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Message_Box()
{
	return x_lang("Message_Box")
}

;Category of the element
Element_getCategory_Action_Message_Box()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Message_Box()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Message_Box()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Message_Box()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Message_Box()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Message_Box(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: x_lang("Title"), content: "String"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Message")})
	parametersToEdit.push({type: "multiLineEdit", id: "message", default: x_lang("Message"), content: "String", contentConvertObjects: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Button Text")})
	parametersToEdit.push({type: "Edit", id: "ButtonLabel", default: x_lang("OK"), content: "String", WarnIfEmpty: true })
	
	parametersToEdit.push({type: "Label", label: x_lang("Timeout")})
	parametersToEdit.push({type: "Radio", id: "IsTimeout", default: "NoTimeout", result: "enum", choices: [x_lang("No timeout"), x_lang("Define timeout")], enum: ["NoTimeout", "Timeout"]})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "PositiveNumber", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: "Seconds", result: "enum", choices: [x_lang("Seconds"), x_lang("Minutes"), x_lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", default: "Normal", result: "enum", choices: [x_lang("Normal") " - " x_lang("Make output variable empty"), x_lang("Throw exception")], enum: ["Normal", "Exception"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Width and height")})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 200], content: "PositiveNumber", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: x_lang("Show cancel button")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: x_lang("Cancel"), content: "String", WarnIfEmpty: true })
	
	parametersToEdit.push({type: "Label", label: x_lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", default: "Exception", result: "enum", choices: [x_lang("Normal"), x_lang("Throw exception")], enum: ["Normal", "Exception"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Result if closed"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfClose", default: "Exception", result: "enum", choices: [x_lang("Normal"), x_lang("Throw exception")], enum: ["Normal", "Exception"]})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Message_Box(Environment, ElementParameters)
{
	return x_lang("Message_Box") " - " ElementParameters.title " - " ElementParameters.message
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Message_Box(Environment, ElementParameters, staticValues)
{	
	
	if (ElementParameters.IsTimeout = "NoTimeout")
	{
		x_Par_Disable("TimeoutUnits")
		x_Par_Disable("Unit")
		x_Par_Disable("OnTimeout")
	}
	else ;Timeout
	{
		x_Par_Enable("TimeoutUnits")
		x_Par_Enable("Unit")
		x_Par_Enable("OnTimeout")
	}
	
	if (ElementParameters.ShowCancelButton = 1) 
	{
		x_Par_Enable("ButtonLabelCancel")
	}
	else
	{
		x_Par_Disable("ButtonLabelCancel")
	}
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Message_Box(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		; timeout is enabled.
		
		; Evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["TimeoutUnits", "Unit", "OnTimeout"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		; calculate end time
		EndTime := A_TickCount
		
		if (EvaluatedParameters.Unit = "Seconds") ;Seconds
			EndTime += EvaluatedParameters.TimeoutUnits * 1000
		else if (EvaluatedParameters.Unit = "Minutes") ;minutes
			EndTime += EvaluatedParameters.TimeoutUnits * 60000
		else if (EvaluatedParameters.Unit = "Hours") ;minutes
			EndTime += EvaluatedParameters.TimeoutUnits * 60000 * 60
		
		; save end time to a execution variable, so we can use it later.
		x_SetExecutionValue(Environment, "EndTime", EndTime)
	}

	;We need those parameters later
	x_SetExecutionValue(Environment, "IfDismiss", EvaluatedParameters.IfDismiss)
	x_SetExecutionValue(Environment, "IfClose", EvaluatedParameters.IfClose)
	x_SetExecutionValue(Environment, "Varname", EvaluatedParameters.Varname)

	if (EvaluatedParameters.ShowCancelButton)
	{
		; cancel button should be shown
		
		; Evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["ButtonLabelCancel"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
	}

	
	;Start building GUI
	guiID := x_GetMyUniqueExecutionID(Environment)
	
	; set gui label, so the function Action_Message_Box_OnClose is called if window gets closed
	gui, %guiID%: +labelAction_Message_Box_On
	
	;Calculate controls width
	widthEdit := EvaluatedParameters.width - 10 * 2
	
	;Calculate the height of the message field
	heightEditMessage := EvaluatedParameters.height
	heightEditMessage -= 30 ;Button height
	heightEditMessage -= 10 * 3 ;Spaces
	if (EvaluatedParameters.isTimeout = "Timeout")
		heightEditMessage -= 10 + 15 ;Timeout text
	
	;Calculate position of first
	yPos := 10

	;Add message field
	gui, %guiID%:add, edit, ReadOnly x10 y%yPos% w%widthEdit% h%heightEditMessage% +hwndHWNDMessage , % EvaluatedParameters.Message
	
	;Calculate position of the next control
	yPos += heightEditMessage + 10
	
	;Add timeout text if a timeout is specified
	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		; add timeout text field
		gui, %guiID%: add, text, y%yPos% w%widthEdit% h15 x10 +hwndHWNDTimeoutText
		
		;Calculate position of the next control
		yPos += 10 + 15
	}
	
	
	if (EvaluatedParameters.ShowCancelButton)
	{
		; Show ok button and cancel button
		widthOneButton := round((widthEdit - 10) / 2)
		gui, %guiID%: add, button, x10 y%yPos% w%widthOneButton% h30 gAction_Message_Box_ButtonOK Default +hwndHWNDButtonOK, % EvaluatedParameters.ButtonLabel
		gui, %guiID%: add, button, X+10 y%yPos% w%widthOneButton% h30 gAction_Message_Box_ButtonCancel +hwndHWNDButtonCancel, % EvaluatedParameters.ButtonLabelCancel
	}
	else
	{
		; show only ok button
		gui, %guiID%: add, button, x10 y%yPos% w%widthEdit% h30 gAction_Message_Box_ButtonOK +hwndHWNDButtonOK Default, % EvaluatedParameters.ButtonLabel
	}
	
	; focus OK button
	guicontrol, %guiID%: focus, % HWNDButtonOK

	;Show GUI
	width := EvaluatedParameters.width
	height := EvaluatedParameters.height
	gui, %guiID%: show, w%Width% h%height%, % EvaluatedParameters.title

	;Set timer if a timeout is set
	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		; create function object for timeout function. Pass the GUI ID to that function, so it can operate on the GUI.
		functionObject:= x_NewFunctionObject(environment, "Action_Message_Box_TimeoutTimer", guiID)
		
		; write some more values as execution varialbes
		x_SetExecutionValue(Environment, "HWNDTimeoutText", HWNDTimeoutText)
		x_SetExecutionValue(Environment, "OnTimeout", EvaluatedParameters.OnTimeout)
		
		; execute the timeout function rightaway
		settimer, % functionObject, -1
	}
}

; React if user clicks on the OK button
Action_Message_Box_ButtonOK()
{
	; get environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)

	; destroy gui
	gui,destroy

	; set user action as output variable
	x_SetVariable(Environment,"A_UserAction", "OK", "thread")
	
	; finish
	x_finish(Environment,"normal")
}

Action_Message_Box_OnClose()
{
	; get environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)

	; destroy gui
	gui,destroy

	; get a value from execution variables
	IfClose := x_GetExecutionValue(Environment, "IfClose")

	; set user action as output variable
	x_SetVariable(Environment,"A_UserAction", "Close", "thread")
	
	; check what to do
	if (IfClose = "exception")
	{
		; finish with exception
		x_finish(Environment, "exception", x_lang("User closed the dialog"))
	}
	else
	{
		; finish without exception
		x_finish(Environment, "normal", x_lang("User closed the dialog"))
	}
}

Action_Message_Box_ButtonCancel()
{
	; get environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)

	; destroy gui
	gui,destroy
	
	; get a value from execution variables
	IfDismiss := x_GetExecutionValue(Environment, "IfDismiss")
	
	; set user action as output variable
	x_SetVariable(Environment, "A_UserAction", "Cancel", "thread")
	
	; check what to do
	if (IfDismiss = "exception")
	{
		; finish with exception
		x_finish(Environment, "exception", x_lang("User cancelled the dialog"))
	}
	else
	{
		; finish without exception
		x_finish(Environment, "normal", x_lang("User cancelled the dialog"))
	}
}

;Timer which will be executed while the window is shown
Action_Message_Box_TimeoutTimer(Environment, uniqueID)
{
	;If the timeout (and thus this timer) is active and the user closes the window, the timer is not autmatically stopped.
	;It may happen that currently an other element is executed.
	;We compare the unique ID which was passed when creating the timer and the current unique ID.
	;If they are not equal, already an other element is being executed.
	guiID := x_GetMyUniqueExecutionID(Environment)
	if (uniqueID != guiID)
		return
	
	; get some values from execution variables
	EndTime := x_GetExecutionValue(Environment, "EndTime")
	HWNDTimeoutText := x_GetExecutionValue(Environment, "HWNDTimeoutText")
	
	; calculate remaining time
	remainingTime := EndTime - a_tickCount
	if (remainingTime <= 0)
	{
		;End of timeout reached
		
		; get a value from execution variables
		OnTimeout := x_GetExecutionValue(Environment, "OnTimeout")

		; destroy gui
		gui, %guiID%: destroy
		
		; set user action as output variable
		x_SetVariable(Environment, "A_UserAction", "Timeout", "thread")
		
		; check what to do
		if (OnTimeout = "Exception")
		{
			; finish with exception
			x_finish(Environment, "exception", x_lang("Timeout reached"))
		}
		else
		{
			; finish without exception
			x_finish(Environment, "normal", x_lang("Timeout reached"))
		}
	}
	else
	{
		;End of timeout not reached. Update the text in the GUI.
		guicontrol, %guiID%:, % HWNDTimeoutText, % (remainingTime // 1000) " " x_lang("Seconds")
		
		;Calculate how many milliseconds we need to wait until the next full second is reached and update timer.
		nextTimerTime := mod(remainingTime, 1000)
		settimer,, % - nextTimerTime
	}
}



;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Message_Box(Environment, ElementParameters)
{
	;Close window if currently opened
	
	; get GUI ID from execution variable
	guiID := x_GetMyUniqueExecutionID(Environment)

	; destroy GUI
	gui, %guiID%: destroy
}






