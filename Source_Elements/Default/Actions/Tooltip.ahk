;Always add this element class name to the global list
AllElementClasses.push("Action_Tooltip")

Element_getPackage_Action_Tooltip()
{
	return "action"
}

Element_getElementType_Action_Tooltip()
{
	return "action"
}

Element_getElementLevel_Action_Tooltip()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Tooltip()
{
	return lang("Tooltip")
}

Element_getIconPath_Action_Tooltip()
{
	return "Source_elements\default\icons\tooltip.png"
}

Element_getCategory_Action_Tooltip()
{
	return lang("User_interaction")
}

Element_getParametrizationDetails_Action_Tooltip(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Text_to_show")})
	parametersToEdit.push({type: "multilineEdit", id: "text", default:  lang("Message"), content: "string",  WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Duration")})
	parametersToEdit.push({type: "Edit", id: "duration", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes")], enum: ["Milliseconds", "Seconds", "Minutes"]})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "follow_mouse", default: 1, label: lang("Follow_Mouse")})

	return parametersToEdit
}

Element_GenerateName_Action_Tooltip(Environment, ElementParameters)
{
	global
	if (ElementParameters.Unit = "Milliseconds")
		duration:=ElementParameters.duration " " lang("ms #Milliseconds")
	if (ElementParameters.Unit = "Seconds")
		duration:=ElementParameters.duration " " lang("s #Seconds")
	if (ElementParameters.Unit = "Minutes")
		duration:=ElementParameters.duration " " lang("m #Minutes")
	
	if (ElementParameters.follow_mouse=1)
		temptext:=lang("Follow_Mouse")
	else
		temptext=
	return lang("Tooltip") ": " ElementParameters.text " - " duration " - " temptext
	
	
}

Element_run_Action_Tooltip(Environment, ElementParameters)
{
	global runActionTooltip_Text=
	global runActionTooltip_Oldx=
	global runActionTooltip_Oldy=
	
	;Evaluate Parameters
	ElementParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["text"])
	if (ElementParameters._error)
	{
		x_finish(Environment, "exception", ElementParameters._errorMessage) 
		return
	}
	
	runActionTooltip_Text:=x_replaceVariables(Environment,ElementParameters.text, "ConvertObjectToString")
	
	;Perform task
	ToolTip,% runActionTooltip_Text,,,13
	if (ElementParameters.follow_mouse =1)
		SetTimer,runActionTooltip_follow_mouse,10,,,13
	
	if (ElementParameters.Unit="Milliseconds") ;Milliseconds
		tempDuration:=ElementParameters.duration
	else if (ElementParameters.Unit="Seconds") ;Seconds
		tempDuration:=ElementParameters.duration * 1000
	else if (ElementParameters.Unit="Minutes") ;minutes
		tempDuration:=ElementParameters.duration * 60000
	
	SetTimer,runActionTooltip_RemoveTooltip,-%tempDuration%
	x_finish(Environment,"normal")
	return
	
}

runActionTooltip_follow_mouse()
{
	global runActionTooltip_Text
	MouseGetPos,runActionTooltip_MouseX,runActionTooltip_MouseY
	if !(runActionTooltip_Oldy=runActionTooltip_Mousey and runActionTooltip_Oldx=runActionTooltip_MouseX)
	{
		runActionTooltip_Oldy:=runActionTooltip_Mousey 
		runActionTooltip_Oldx:=runActionTooltip_MouseX
		ToolTip,%runActionTooltip_Text%,,,13
	}
}
runActionTooltip_RemoveTooltip()
{
	SetTimer,runActionTooltip_follow_mouse,off
	ToolTip,,,,13
}

Element_stop_Action_Tooltip(Environment, ElementParameters)
{
	runActionTooltip_RemoveTooltip()
}