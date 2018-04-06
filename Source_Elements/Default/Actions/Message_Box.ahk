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
	return lang("Message_Box")
}

;Category of the element
Element_getCategory_Action_Message_Box()
{
	return lang("User_interaction")
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

;Icon path which will be shown in the background of the element
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
	
	parametersToEdit.push({type: "Label", label: lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Title"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Message")})
	parametersToEdit.push({type: "Edit", id: "message", default: lang("Message"), content: "String", multiline: true})
	parametersToEdit.push({type: "Label", label: lang("Button Text")})
	parametersToEdit.push({type: "Edit", id: "ButtonLabel", default: lang("OK"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Timeout")})
	parametersToEdit.push({type: "Radio", id: "IsTimeout", default: 1, result: "enum", choices: [lang("No timeout"), lang("Define timeout")], enum: ["NoTimeout", "Timeout"]})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: "Seconds", result: "enum", choices: [lang("Seconds"), lang("Minutes"), lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]})
	parametersToEdit.push({type: "Label", label: lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", default: "Normal", result: "enum", choices: [lang("Normal") " - " lang("Make output variable empty"), lang("Throw exception")], enum: ["Normal", "Exception"]})
	
	;~ parametersToEdit.push({type: "Label", label: lang("Position")}) ;TODO
	;~ parametersToEdit.push({type: "Radio", id: "Position", default: 1, choices: [lang("In the middle of screen"), lang("Beneath current mouse position"), lang("Define coordinates")]})
	;~ parametersToEdit.push({type: "Label", label: lang("Coordinates") " (x,y)", size: "small"})
	;~ parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: ["A_ScreenWidth/2", "A_ScreenHeight/2"]})
	;~ parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionMove_WindowMouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Width and height")})
	;~ parametersToEdit.push({type: "Radio", id: "Size", default: 1, choices: [lang("Automatic"), lang("Define width and height"), result: "enum", enum: ["automatic", "predefined"]]})
	;~ parametersToEdit.push({type: "Label", label: lang("Width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 200], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: lang("Show cancel button")})
	parametersToEdit.push({type: "Label", label: lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: lang("Cancel"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", choices: [lang("Normal"), lang("Throw exception")], default: 1})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Message_Box(Environment, ElementParameters)
{
	return lang("Message_Box") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Message_Box(Environment, ElementParameters)
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
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	width:=EvaluatedParameters.width
	height:=EvaluatedParameters.height
	
	if width is not number
	{
		x_finish(Environment, "exception", lang("%1% is not a number.",lang("Width '%1%'",width))) 
		return
	}
	if height is not number
	{
		x_finish(Environment, "exception", lang("%1% is not a number.",lang("Height '%1%'",height))) 
		return
	}

	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["TimeoutUnits", "Unit", "OnTimeout"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		TimeoutUnits:=ElementParameters.TimeoutUnits
		if TimeoutUnits is not number
		{
			x_finish(Environment, "exception", lang("%1% is not a number.",lang("Timeout '%1%'",TimeoutUnits))) 
			return
		}
		
		EndTime := A_TickCount
		
		if (ElementParameters.Unit="Seconds") ;Seconds
			EndTime+=TimeoutUnits * 1000
		else if (ElementParameters.Unit="Minutes") ;minutes
			EndTime+=TimeoutUnits * 60000
		else if (ElementParameters.Unit="Hours") ;minutes
			EndTime+=TimeoutUnits * 60000 * 60
		
		x_SetExecutionValue(Environment, "EndTime",EndTime) ;We need this value later
	}
	;We need those parameters later
	x_SetExecutionValue(Environment, "IfDismiss",EvaluatedParameters.IfDismiss)


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
	guiID:=x_GetMyUniqueExecutionID(Environment)
	gui,%guiID%:+labelAction_Message_Box_On
	
	;Calculate controls width
	widthEdit:=width-10*2
	heightEditMessage:=height
	heightEditMessage -= 30 ;Button height
	heightEditMessage -= 10*3 ;Spaces
	if (EvaluatedParameters.isTimeout = "Timeout")
		heightEditMessage -= 10 + 15 ;Timeout text
	
	;Add message field
	gui,%guiID%:add,edit, ReadOnly x10 y10 w%widthEdit% h%heightEditMessage% +hwndHWNDMessage , % EvaluatedParameters.Message
	
	;move the Text field beneath the message field
	yPos:=10+10+heightEditMessage
	guicontrol,%guiID%:move,% HWNDText,x10 y%yPos%
	
	;Calculate position of the next control
	yPos+=10+heightEditText
	
	;Add timeout text if a timeout is specified
	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		gui,%guiID%:add,text, y%yPos% w%widthEdit% h15 x10 +hwndHWNDTimeoutText
		yPos+=10+15 ;Calculate position of the next control
	}
	
	
	if (EvaluatedParameters.ShowCancelButton)
	{
		;Show two buttons
		widthOneButton:=round((widthEdit-10)/2)
		gui,%guiID%:add,button,x10 y%yPos% w%widthOneButton% h30  gAction_Message_Box_ButtonOK Default +hwndHWNDButtonOK,% EvaluatedParameters.ButtonLabel
		gui,%guiID%:add,button,X+10 y%yPos% w%widthOneButton% h30  gAction_Message_Box_ButtonCancel +hwndHWNDButtonCancel,% EvaluatedParameters.ButtonLabelCancel
	}
	else
	{
		gui,%guiID%:add,button,x10 y%yPos% w%widthEdit% h30  gAction_Message_Box_ButtonOK +hwndHWNDButtonOK Default ,% EvaluatedParameters.ButtonLabel
	}
	
	;Show GUI
	guicontrol,%guiID%:focus,% HWNDButtonOK
	gui,%guiID%:show,w%Width% h%height% ,% EvaluatedParameters.title

	;Set timer if a timeout is set
	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		functionObject:= x_NewExecutionFunctionObject(environment, "Action_Message_Box_TimeoutTimer",x_GetMyUniqueExecutionID(Environment)) ;Pass the current unique ID
		x_SetExecutionValue(Environment, "HWNDTimeoutText",HWNDTimeoutText)
		x_SetExecutionValue(Environment, "OnTimeout",EvaluatedParameters.OnTimeout)
		x_SetExecutionValue(Environment, "functionObjectTimer",functionObjectTimer)
		settimer,% functionObject,-1
	}

	return
	
	
}

;Handle user input
Action_Message_Box_ButtonOK()
{
	Environment:=x_GetMyEnvironmentFromExecutionID(A_Gui)
	x_SetVariable(Environment,"A_UserAction", "OK", "thread")
	
	gui,destroy
	x_finish(Environment,"normal")
}

Action_Message_Box_OnClose()
{
	Environment:=x_GetMyEnvironmentFromExecutionID(A_Gui)
	gui,destroy
	IfDismiss:=x_GetExecutionValue(Environment, "IfDismiss")
	x_SetVariable(Environment,"A_UserAction", "Cancel", "thread")
	
	if (IfDismiss = "exception")
	{
		x_finish(Environment,"exception", lang("User closed the dialog"))
	}
	else
	{
		x_finish(Environment,"normal")
	}
}

Action_Message_Box_ButtonCancel()
{
	Environment:=x_GetMyEnvironmentFromExecutionID(A_Gui)
	gui,destroy
	IfDismiss:=x_GetExecutionValue(Environment, "IfDismiss")
	x_SetVariable(Environment,"A_UserAction", "Cancel", "thread")
	
	if (IfDismiss = "exception")
	{
		x_finish(Environment,"exception", lang("User cancelled the dialog"))
	}
	else
	{
		x_finish(Environment,"normal")
	}
}

;Timer which will be executed while the window is shown
Action_Message_Box_TimeoutTimer(Environment, uniqueID)
{
	;If the timeout (and thus this timer) is active and the user closes the window, the timer is not autmatically stopped.
	;It may happen that currently an other element is executed.
	;We compare the unique ID which was passed when creating the timer and the current unique ID.
	;If they are not equal, already an other element is being executed.
	guiID:=x_GetMyUniqueExecutionID(Environment)
	if (uniqueID != guiID)
		return
	
	EndTime:=x_GetExecutionValue(Environment, "EndTime")
	HWNDTimeoutText:=x_GetExecutionValue(Environment, "HWNDTimeoutText")
	OnTimeout:=x_GetExecutionValue(Environment, "OnTimeout")
	
	remainingTime:=EndTime - a_tickCount
	if (remainingTime <= 0)
	{
		;End of timeout reached
		gui,%guiID%:destroy
		x_SetVariable(Environment,"A_UserAction", "Timeout", "thread")
		if (OnTimeout = "Exception")
		{
			x_finish(Environment,"exception", lang("Timeout reached"))
		}
		else
		{
			x_finish(Environment,"normal")
		}
	}
	else
	{
		;End of timeout not reached. Update the text in the GUI.
		guicontrol,%guiID%:,% HWNDTimeoutText,% (remainingTime // 1000) " " lang("Seconds")
		
		;Calculate how many milliseconds we need to wait until the next full second is reached and update timer.
		nextTimerTime:=mod(remainingTime,1000)
		settimer,,% - nextTimerTime
	}
}



;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Message_Box(Environment, ElementParameters)
{
	guiID:=x_GetMyUniqueExecutionID(Environment)
	gui,%guiID%:destroy
}






