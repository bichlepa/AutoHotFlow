;Always add this element class name to the global list
x_RegisterElementClass("Condition_Confirmation_Dialog")

;Element type of the element
Element_getElementType_Condition_Confirmation_Dialog()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_Confirmation_Dialog()
{
	return x_lang("Confirmation_Dialog")
}

;Category of the element
Element_getCategory_Condition_Confirmation_Dialog()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Confirmation_Dialog()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Confirmation_Dialog()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_Confirmation_Dialog()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Confirmation_Dialog()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Confirmation_Dialog(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: x_lang("Title"), content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Message")})
	parametersToEdit.push({type: "Edit", id: "message", default: x_lang("Message"), content: "String", multiline: true})
	parametersToEdit.push({type: "Label", label: x_lang("Button Text")})
	parametersToEdit.push({type: "Label", label: x_lang("Button '%1%'",x_lang("Yes")), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelYes", default: x_lang("Yes"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: x_lang("Button '%1%'",x_lang("No")), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelNo", default: x_lang("No"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: x_lang("Timeout")})
	parametersToEdit.push({type: "Checkbox", id: "IsTimeout", default: false, label: x_lang("Timeout enabled")})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: "Seconds", result: "enum", choices: [x_lang("Seconds"), x_lang("Minutes"), x_lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]})
	parametersToEdit.push({type: "Label", label: x_lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", default: "Exception", result: "enum", choices: [x_lang("Yes"), x_lang("No"), x_lang("Throw exception")], enum: ["Yes", "No", "Exception"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Width and height")})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 200], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: x_lang("Show cancel button")})
	parametersToEdit.push({type: "Label", label: x_lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: x_lang("Cancel"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: x_lang("Default Button"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "DefaultButton", default: "No", result: "enum", choices: [x_lang("Yes"), x_lang("No"), x_lang("Cancel")], enum: ["Yes", "No", "Cancel"]})
	parametersToEdit.push({type: "Label", label: x_lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", default: "Exception", result: "enum", choices: [x_lang("Yes"), x_lang("No"), x_lang("Throw exception")], enum: ["Yes", "No", "Exception"]})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Confirmation_Dialog(Environment, ElementParameters)
{
	return x_lang("Confirmation_Dialog") "`n" ElementParameters.title ", " ElementParameters.message
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Confirmation_Dialog(Environment, ElementParameters)
{	
	; check parameter IsTimeout
	if (not ElementParameters.IsTimeout)
	{
		; timeout is not checked. Disable timeout properties
		x_Par_Disable("TimeoutUnits")
		x_Par_Disable("Unit")
		x_Par_Disable("OnTimeout")
	}
	else
	{
		; timeout is checked. Enable timeout properties
		x_Par_Enable("TimeoutUnits")
		x_Par_Enable("Unit")
		x_Par_Enable("OnTimeout")
	}
	
	; enable ButtonLabelCancel if ShowCancelButton is checked
	if (ElementParameters.ShowCancelButton = 1) 
	{
		x_Par_Enable("ButtonLabelCancel")
	}
	else
	{
		x_Par_Disable("ButtonLabelCancel")
		if (ElementParameters.DefaultButton = "Cancel")
		{
			x_Par_SetValue("DefaultButton", "No")
		}
	}
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Confirmation_Dialog(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["TimeoutUnits", "Unit", "OnTimeout", "ButtonLabelCancel"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	width := EvaluatedParameters.width
	height := EvaluatedParameters.height
	
	; check width and height
	
	if (not (width > 0))
	{
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "width", width)) 
		return
	}
	if (not (height > 0))
	{
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "height", height)) 
		return
	}

	if (EvaluatedParameters.isTimeout)
	{
		; evaluate the timeout parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["TimeoutUnits", "Unit", "OnTimeout"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		; check timeout value
		if (not (EvaluatedParameters.TimeoutUnits > 0))
		{
			x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "TimeoutUnits", EvaluatedParameters.TimeoutUnits)) 
			return
		}
		
		; calculate the timestamp after timeout
		EndTime := A_TickCount
		
		if (ElementParameters.Unit = "Seconds") ;Seconds
			EndTime += ElementParameters.TimeoutUnits * 1000
		else if (ElementParameters.Unit = "Minutes") ;minutes
			EndTime += ElementParameters.TimeoutUnits * 60000
		else if (ElementParameters.Unit = "Hours") ;minutes
			EndTime += ElementParameters.TimeoutUnits * 60000 * 60
		
		;We need this value later
		x_SetExecutionValue(Environment, "EndTime", EndTime)
	}
	;We need those parameters later
	x_SetExecutionValue(Environment, "IfDismiss", EvaluatedParameters.IfDismiss)

	; check cancel button label if cancel button is required
	if (EvaluatedParameters.ShowCancelButton)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["ButtonLabelCancel"])
		if (ElementParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
	}

	
	;Start building GUI
	guiID := x_GetMyUniqueExecutionID(Environment)
	gui, %guiID%: +labelCondition_Confirmation_Dialog_On ;This label leads to a jump label beneath. It's needed if user closes the window
	
	;Calculate controls width
	widthEdit := width - 10 * 2
	heightEditMessage := height
	heightEditMessage -= 30 ;Button height
	heightEditMessage -= 10 * 3 ;Spaces
	if (EvaluatedParameters.isTimeout)
		heightEditMessage -= 10 + 15 ;Timeout text
	
	;Add message field
	gui, %guiID%: add, edit, ReadOnly x10 y10 w%widthEdit% h%heightEditMessage% +hwndHWNDMessage, % EvaluatedParameters.Message
	
	;move the Text field beneath the message field
	yPos := 10 + 10 + heightEditMessage
	guicontrol, %guiID%: move, % HWNDText, x10 y%yPos%
	
	;Calculate position of the next control
	yPos += 10 + heightEditText
	
	;Add timeout text if a timeout is specified
	if (EvaluatedParameters.isTimeout)
	{
		gui, %guiID%: add, text, y%yPos% w%widthEdit% h15 x10 +hwndHWNDTimeoutText
		yPos += 10 + 15 ;Calculate position of the next control
	}
	
	
	if (EvaluatedParameters.ShowCancelButton)
	{
		;Show three buttons
		widthOneButton := round((widthEdit - 20) / 3)
		gui, %guiID%: add, button, x10  y%yPos% w%widthOneButton% h30 gCondition_Confirmation_Dialog_ButtonYes +hwndHWNDButtonOYes, % EvaluatedParameters.ButtonLabelYes
		gui, %guiID%: add, button, X+10 y%yPos% w%widthOneButton% h30 gCondition_Confirmation_Dialog_ButtonNo +hwndHWNDButtonNo, % EvaluatedParameters.ButtonLabelNo
		gui, %guiID%: add, button, X+10 y%yPos% w%widthOneButton% h30 gCondition_Confirmation_Dialog_ButtonCancel +hwndHWNDButtonCancel, % EvaluatedParameters.ButtonLabelCancel
	}
	else
	{
		;Show two Buttons
		widthOneButton := round((widthEdit - 10) / 2)
		gui, %guiID%: add, button, x10  y%yPos% w%widthOneButton% h30 gCondition_Confirmation_Dialog_ButtonYes +hwndHWNDButtonYes, % EvaluatedParameters.ButtonLabelYes
		gui, %guiID%: add, button, X+10 y%yPos% w%widthOneButton% h30 gCondition_Confirmation_Dialog_ButtonNo +hwndHWNDButtonNo, % EvaluatedParameters.ButtonLabelNo
	}
	
	; focus default button
	DefaultButton := EvaluatedParameters.DefaultButton
	guicontrol, %guiID%: +default, % HWNDButton%DefaultButton%
	guicontrol, %guiID%: focus, % HWNDButton%DefaultButton%

	;Show GUI
	gui, %guiID%: show, w%Width% h%height%, % EvaluatedParameters.title

	;Set timer if a timeout is set
	if (EvaluatedParameters.isTimeout)
	{
		;Pass the current unique ID
		functionObject := x_NewFunctionObject(environment, "Condition_Confirmation_Dialog_TimeoutTimer", x_GetMyUniqueExecutionID(Environment))
		x_SetExecutionValue(Environment, "HWNDTimeoutText", HWNDTimeoutText)
		x_SetExecutionValue(Environment, "OnTimeout", EvaluatedParameters.OnTimeout)
		x_SetExecutionValue(Environment, "functionObject", functionObject)
		settimer, % functionObject, -1
	}
	return
}

; User clicked on button "yes"
Condition_Confirmation_Dialog_ButtonYes()
{
	; get the environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)

	; stop timer if enabled
	functionObject := x_GetExecutionValue(environment, "functionObject")
	if (functionObject)
	{
		SetTimer, % functionObject, delete
	}

	; set result variable
	x_SetVariable(Environment, "A_UserAction", "Yes", "thread")
	
	; destroy gui
	gui, destroy

	; finish
	x_finish(Environment, "Yes")
}
; User clicked on button "no"
Condition_Confirmation_Dialog_ButtonNo()
{
	; get the environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)
	
	; stop timer if enabled
	functionObject := x_GetExecutionValue(environment, "functionObject")
	if (functionObject)
	{
		SetTimer, % functionObject, delete
	}

	; set result variable
	x_SetVariable(Environment, "A_UserAction", "No", "thread")
	
	; destroy gui
	gui, destroy

	; finish
	x_finish(Environment, "No")
}

; User closed window
Condition_Confirmation_Dialog_OnClose()
{
	; get the environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)
	
	; stop timer if enabled
	functionObject := x_GetExecutionValue(environment, "functionObject")
	if (functionObject)
	{
		SetTimer, % functionObject, delete
	}

	; set result variable
	x_SetVariable(Environment, "A_UserAction", "Cancel", "thread")
	
	; destroy gui
	gui, destroy

	; set result according to the parameter
	IfDismiss := x_GetExecutionValue(Environment, "IfDismiss")
	x_finish(Environment, IfDismiss, x_lang("User closed the dialog"))
}

; User clicked on button "cancel"
Condition_Confirmation_Dialog_ButtonCancel()
{
	; get the environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(A_Gui)

	; stop timer if enabled
	functionObject := x_GetExecutionValue(environment, "functionObject")
	if (functionObject)
	{
		SetTimer, % functionObject, delete
	}

	; set result variable
	x_SetVariable(Environment, "A_UserAction", "Cancel", "thread")

	; destroy gui
	gui, destroy
	
	; set result according to the parameter
	IfDismiss := x_GetExecutionValue(Environment, "IfDismiss")
	x_finish(Environment, IfDismiss, x_lang("User cancelled the dialog"))
}

;Timer which will be executed while the window is shown
Condition_Confirmation_Dialog_TimeoutTimer(Environment, uniqueID)
{
	; get some information
	guiID := x_GetMyUniqueExecutionID(Environment)
	EndTime := x_GetExecutionValue(Environment, "EndTime")
	functionObject := x_GetExecutionValue(environment, "functionObject")
	OnTimeout := x_GetExecutionValue(Environment, "OnTimeout")
	
	; calculate remaining time
	remainingTime := EndTime - a_tickCount
	if (remainingTime <= 0)
	{
		; timeout reached
		; stop the timer
		SetTimer, % functionObject, delete
		
		; destroy gui
		gui, %guiID%:destroy

		; set result variable
		x_SetVariable(Environment, "A_UserAction", "Timeout", "thread")
		
		; set result according to the parameter
		x_finish(Environment, OnTimeout, x_lang("Timeout reached"))
	}
	else
	{
		;End of timeout not reached. Update the text in the GUI.
		HWNDTimeoutText := x_GetExecutionValue(Environment, "HWNDTimeoutText")
		guicontrol, %guiID%:, % HWNDTimeoutText, % ((remainingTime - 1) // 1000) " " x_lang("Seconds") " (" x_lang(OnTimeout) ")"
		
		;Calculate how many milliseconds we need to wait until the next full second is reached and update timer.
		nextTimerTime := mod(remainingTime - 1, 1000)
		SetTimer, % functionObject, % nextTimerTime + 1
	}
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Confirmation_Dialog(Environment, ElementParameters)
{
	; stop timer if enabled
	functionObject := x_GetExecutionValue(environment, "functionObject")
	if (functionObject)
	{
		SetTimer, % functionObject, delete
	}

	; destroy the gui
	guiID := x_GetMyUniqueExecutionID(Environment)
	gui, %guiID%:destroy
}






