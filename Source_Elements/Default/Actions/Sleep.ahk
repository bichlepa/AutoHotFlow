;Always add this element class name to the global list
AllElementClasses.push("Action_Sleep")

Element_getPackage_Action_Sleep()
{
	return "action"
}

Element_getElementType_Action_Sleep()
{
	return "action"
}

Element_getName_Action_Sleep()
{
	return lang("Sleep")
}

Element_getIconPath_Action_Sleep()
{
	return "Source_elements\default\icons\sleep.ico"
}

Element_getCategory_Action_Sleep()
{
	return lang("Flow_control")
}

Element_getParameters_Action_Sleep()
{
	return ["duration", "Unit"]
}

Element_getParametrizationDetails_Action_Sleep(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label:  lang("Duration")})
	parametersToEdit.push({type: "edit", id: "Duration", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes")]})

	return parametersToEdit
}

Element_GenerateName_Action_Sleep(Environment, ElementParameters)
{
	global
	;~ d(ElementParameters)
	if (ElementParameters.Unit = 1)
		duration:=ElementParameters.duration " " lang("ms #Milliseconds")
	if (ElementParameters.Unit = 2)
		duration:=ElementParameters.duration " " lang("s #Seconds")
	if (ElementParameters.Unit = 3)
		duration:=ElementParameters.duration " " lang("m #Minutes")
	
	return lang("Sleep") ": " duration
	
	
}

Element_run_Action_Sleep(Environment, ElementParameters)
{
	
	if (ElementParameters.Unit=1) ;Milliseconds
		tempDuration:=ElementParameters.duration
	else if (ElementParameters.Unit=2) ;Seconds
		tempDuration:=ElementParameters.duration * 1000
	else if (ElementParameters.Unit=3) ;minutes
		tempDuration:=ElementParameters.duration * 60000
	
	functionObject:= x_NewExecutionFunctionObject(environment, "Action_Sleep_EndSleep", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	
	SetTimer,% functionObject,-%tempDuration%
	;~ d(functionObject)
	return
	
	
}

Element_stop_Action_Sleep(Environment, ElementParameters)
{
	;~ d(Environment)
	functionObject:=x_getExecutionValue(Environment, "functionObject")
	;~ d(functionObject)
	SetTimer, % functionObject, off
}

Action_Sleep_EndSleep(Environment, ElementParameters="")
{
	;~ d(ElementParameters)
	x_finish(Environment,"normal")
}