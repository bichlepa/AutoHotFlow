;Always add this element class name to the global list
AllElementClasses.push("Action_Input_Box")

;Element type of the element
Element_getElementType_Action_Input_Box()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Input_Box()
{
	return lang("Input_Box")
}

;Category of the element
Element_getCategory_Action_Input_Box()
{
	return lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Input_Box()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Input_Box()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Input_Box()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Input_Box()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Input_Box()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push("Varname")
	parametersToEdit.push("title")
	parametersToEdit.push("message")
	parametersToEdit.push("OnlyNumbers")
	parametersToEdit.push("MaskUserInput")
	parametersToEdit.push("MultilineEdit")
	parametersToEdit.push("MultilineEditRows")
	parametersToEdit.push("defaultText")
	parametersToEdit.push("ButtonLabel")
	parametersToEdit.push("IsTimeout")
	parametersToEdit.push("TimeoutUnits")
	parametersToEdit.push("Unit")
	parametersToEdit.push("OnTimeout")
	parametersToEdit.push("Width")
	parametersToEdit.push("Height")
	parametersToEdit.push("ShowCancelButton")
	parametersToEdit.push("ButtonLabelCancel")
	parametersToEdit.push("IfDismiss")
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Input_Box(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "UserInput", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Title"), content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Message")})
	parametersToEdit.push({type: "Edit", id: "message", default: lang("Please, write something"), multiline: true, content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Edit field")})
	parametersToEdit.push({type: "Checkbox", id: "OnlyNumbers", default: 0, label: lang("Only allow numbers")})
	parametersToEdit.push({type: "Checkbox", id: "MaskUserInput", default: 0, label: lang("Mask user's input")})
	parametersToEdit.push({type: "Checkbox", id: "MultilineEdit", default: 0, label: lang("Use a multiline edit field")})
	parametersToEdit.push({type: "Label", label: lang("Count of lines"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "MultilineEditRows", default: 4, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Default value"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "defaultText", default: "", multiline: true, content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Button Text")})
	parametersToEdit.push({type: "Edit", id: "ButtonLabel", default: lang("OK"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Timeout")})
	parametersToEdit.push({type: "Radio", id: "IsTimeout", default: 1, result: "enum", choices: [lang("No timeout"), lang("Define timeout")], enum: ["NoTimeout", "Timeout"]})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: "Seconds", result: "enum", choices: [lang("Seconds"), lang("Minutes"), lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]})
	parametersToEdit.push({type: "Label", label: lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", default: "Normal", result: "enum", choices: [lang("Normal") " - " lang("Make output variable empty"), lang("Throw exception")], enum: ["Normal", "Exception"]})
	parametersToEdit.push({type: "Label", label: lang("Width and height")})
	;~ parametersToEdit.push({type: "Radio", id: "Size", default: 1, choices: [lang("Automatic"), lang("Define width and height")]}) ;No automatic size yet
	;~ parametersToEdit.push({type: "Label", label: lang("Width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 250], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: lang("Show cancel button")})
	parametersToEdit.push({type: "Label", label: lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: lang("Cancel"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", default: "Normal", result: "enum", choices: [lang("Normal") " - " lang("Make output variable empty"), lang("Throw exception")], enum: ["Normal", "Exception"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Input_Box(Environment, ElementParameters)
{
	if (strlen(ElementParameters.message)>100)
	{
		return lang("Input_box") ": " ElementParameters.title " - " substr(ElementParameters.message,1,100) " ... "
	}
	else
		return lang("Input_box") ": " ElementParameters.title " - " ElementParameters.message
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Input_Box(Environment, ElementParameters)
{	
	
	if (ElementParameters.OnlyNumbers = 1)
	{
		x_Par_Disable("MaskUserInput")
	}
	else
	{
		x_Par_Enable("MaskUserInput")
	}
	
	if (ElementParameters.MaskUserInput = 1) 
	{
		x_Par_Disable("OnlyNumbers")
		x_Par_Disable("MultilineEdit")
	}
	else
	{
		x_Par_Enable("OnlyNumbers")
		x_Par_Enable("MultilineEdit")
	}
	
	if (ElementParameters.MultilineEdit = 1) 
	{
		x_Par_Disable("MaskUserInput")
		x_Par_Enable("MultilineEditRows")
	}
	else
	{
		if (ElementParameters.OnlyNumbers = 0) 
		{
			x_Par_Enable("MaskUserInput")
			GuiControl,Enable,ElementParameters.MaskUserInput
		}
		x_Par_Disable("MultilineEditRows")
	}
	
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
Element_run_Action_Input_Box(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["MultilineEditRows", "TimeoutUnits", "Unit", "OnTimeout", "ButtonLabelCancel"]) ;Evaluate some parameters later, if they are needed
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
	x_SetExecutionValue(Environment, "Varname",EvaluatedParameters.Varname)
	
	if (EvaluatedParameters.MaskUserInput)
		tempMaskInput:="Password"
	if (EvaluatedParameters.OnlyNumbers)
		tempMaskInput:="Number"
	if (EvaluatedParameters.MultilineEdit)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["MultilineEditRows"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		MultilineEditRows:= EvaluatedParameters.MultilineEditRows
		
		if MultilineEditRows is not number
		{
			x_finish(Environment, "exception", lang("%1% is not a number.",lang("Row count '%1%'",MultilineEditRows))) 
			return
		}
		tempRows:="r" MultilineEditRows
	}
	else
	{
		tempRows:="r1"
	}
	
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
	gui,%guiID%:+labelAction_Input_Box_On
	
	;Calculate controls width
	widthEdit:=width-10*2
	
	;at first add the edit field and get the size of the edit field
	gui,%guiID%:add,edit, w%widthEdit% %tempMaskInput% %tempRows% hwndHWNDText, % EvaluatedParameters.defaultText
	controlgetpos,,,,heightEditText,,ahk_id %HWNDText%
	x_SetExecutionValue(Environment, "HWNDText",HWNDText)
	
	;Calculate the height of the message field
	heightEditMessage:=height
	heightEditMessage -= 30 ;Button height
	heightEditMessage -= heightEditText ;Edit text height
	heightEditMessage -= 10*4 ;Spaces
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
		gui,%guiID%:add,button,x10 y%yPos% w%widthOneButton% h30  gActionInput_BoxButtonOK Default +hwndHWNDButtonOK,% EvaluatedParameters.ButtonLabel
		gui,%guiID%:add,button,X+10 y%yPos% w%widthOneButton% h30  gActionInput_BoxButtonCancel +hwndHWNDButtonCancel,% EvaluatedParameters.ButtonLabelCancel
	}
	else
	{
		gui,%guiID%:add,button,x10 y%yPos% w%widthEdit% h30  gActionInput_BoxButtonOK +hwndHWNDButtonOK Default ,% tEvaluatedParameters.ButtonLabel
	}
	
	;Show GUI
	guicontrol,%guiID%:focus,% HWNDButtonOK
	gui,%guiID%:show,w%Width% h%height% ,% EvaluatedParameters.title

	;Set timer if a timeout is set
	if (EvaluatedParameters.isTimeout = "Timeout")
	{
		functionObject:= x_NewExecutionFunctionObject(environment, "Action_Input_Box_TimeoutTimer",x_GetMyUniqueExecutionID(Environment)) ;Pass the current unique ID
		x_SetExecutionValue(Environment, "HWNDTimeoutText",HWNDTimeoutText)
		x_SetExecutionValue(Environment, "OnTimeout",EvaluatedParameters.OnTimeout)
		x_SetExecutionValue(Environment, "functionObjectTimer",functionObjectTimer)
		settimer,% functionObject,-1
	}
}

;Handle user input
ActionInput_BoxButtonOK()
{
	Environment:=x_GetMyEnvironmentFromExecutionID(A_Gui)
	HWNDText:=x_GetExecutionValue(Environment, "HWNDText")
	Varname:=x_GetExecutionValue(Environment, "Varname")
	
	guicontrolget,value,,% HWNDText
	x_SetVariable(Environment,Varname, value)
	x_SetVariable(Environment,"A_UserAction", "OK", "thread")
	
	gui,destroy
	x_finish(Environment,"normal")
}

Action_Input_Box_OnClose()
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
		Varname:=x_GetExecutionValue(Environment, "Varname")
		x_SetVariable(Environment,Varname, "")
		x_finish(Environment,"normal")
	}
}

ActionInput_BoxButtonCancel()
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
		Varname:=x_GetExecutionValue(Environment, "Varname")
		x_SetVariable(Environment,Varname, "")
		x_finish(Environment,"normal")
	}
}

;Timer which will be executed while the window is shown
Action_Input_Box_TimeoutTimer(Environment, uniqueID)
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
			Varname:=x_GetExecutionValue(Environment, "Varname")
			x_SetVariable(Environment,Varname, "")
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
Element_stop_Action_Input_Box(Environment, ElementParameters)
{
	;Close window if currently opened
	guiID:=x_GetMyUniqueExecutionID(Environment)
	gui,%guiID%:destroy
}






