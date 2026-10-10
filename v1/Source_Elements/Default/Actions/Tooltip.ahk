
;Name of the element
Element_getName_Action_Tooltip()
{
	return x_lang("Tooltip")
}

;Category of the element
Element_getCategory_Action_Tooltip()
{
	return x_lang("User_interaction")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Tooltip()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Tooltip()
{
	return "tooltip.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Tooltip()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Tooltip(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Text_to_show")})
	parametersToEdit.push({type: "multilineEdit", id: "text", default:  x_lang("Message"), content: "string", contentConvertObjects: true, WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Duration")})
	parametersToEdit.push({type: "Edit", id: "duration", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [x_lang("Milliseconds"), x_lang("Seconds"), x_lang("Minutes")], enum: ["Milliseconds", "Seconds", "Minutes"]})
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "follow_mouse", default: 1, label: x_lang("Follow_Mouse")})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Tooltip(Environment, ElementParameters)
{
	global
	if (ElementParameters.Unit = "Milliseconds")
		duration := ElementParameters.duration " " x_lang("ms #Milliseconds")
	if (ElementParameters.Unit = "Seconds")
		duration := ElementParameters.duration " " x_lang("s #Seconds")
	if (ElementParameters.Unit = "Minutes")
		duration := ElementParameters.duration " " x_lang("m #Minutes")
	
	if (ElementParameters.follow_mouse=1)
		temptext := x_lang("Follow_Mouse")
	else
		temptext := ""
	
	return x_lang("Tooltip") ": " ElementParameters.text " - " duration " - " temptext
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Tooltip(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Tooltip(Environment, ElementParameters)
{
	global runActionTooltip_Text=
	global runActionTooltip_Oldx=
	global runActionTooltip_Oldy=
	
	;Evaluate Parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	runActionTooltip_Text := EvaluatedParameters.text
	
	; Show tooltip
	ToolTip, % runActionTooltip_Text,,, 13

	if (EvaluatedParameters.follow_mouse)
	{
		; we need to follow the mouse. Set task timer for that
		SetTimer, runActionTooltip_follow_mouse, 10,,, 13
	}
	
	; calculate duration in ms
	if (EvaluatedParameters.Unit = "Milliseconds") ;Milliseconds
		tempDuration := EvaluatedParameters.duration
	else if (EvaluatedParameters.Unit = "Seconds") ;Seconds
		tempDuration := EvaluatedParameters.duration * 1000
	else if (EvaluatedParameters.Unit = "Minutes") ;minutes
		tempDuration := EvaluatedParameters.duration * 60000
	
	; set timer which will remove the tooltip
	SetTimer, runActionTooltip_RemoveTooltip, -%tempDuration%
	
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Tooltip(Environment, ElementParameters)
{
	runActionTooltip_RemoveTooltip()
}

; loop label, which moves the tooltip if mouse moves
runActionTooltip_follow_mouse()
{
	global runActionTooltip_Text
	static runActionTooltip_Oldy, runActionTooltip_Oldx

	; get mouse position
	MouseGetPos, runActionTooltip_MouseX, runActionTooltip_MouseY

	; check whether mouse position has changed
	if !(runActionTooltip_Oldy = runActionTooltip_Mousey and runActionTooltip_Oldx = runActionTooltip_MouseX)
	{
		; mouse position has changed. Remember current position
		runActionTooltip_Oldy := runActionTooltip_Mousey 
		runActionTooltip_Oldx := runActionTooltip_MouseX

		; move tooltip
		ToolTip, %runActionTooltip_Text%,,, 13
	}
}

; removes the tooltip
runActionTooltip_RemoveTooltip()
{
	; stop the timer which makes the tooltip follow the mouse
	SetTimer, runActionTooltip_follow_mouse, off

	; disable tooltip
	ToolTip,,,, 13
}
