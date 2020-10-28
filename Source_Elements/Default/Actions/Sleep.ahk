;Always add this element class name to the global list
x_RegisterElementClass("Action_Sleep")

;Element type of the element
Element_getElementType_Action_Sleep()
{
	return "action"
}

;Name of the element
Element_getName_Action_Sleep()
{
	return lang("Sleep")
}

;Category of the element
Element_getCategory_Action_Sleep()
{
	return lang("Flow_control")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Sleep()
{
	return "action"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Sleep()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Sleep()
{
	return "Source_elements\default\icons\sleep.ico"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Sleep()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Sleep(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label:  lang("Duration")})
	parametersToEdit.push({type: "edit", id: "Duration", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes")], enum: ["Milliseconds", "Seconds", "Minutes"]})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Sleep(Environment, ElementParameters)
{
	global
	;~ d(ElementParameters)
	if (ElementParameters.Unit = "Milliseconds")
		duration:=ElementParameters.duration " " lang("ms #Milliseconds")
	if (ElementParameters.Unit = "Seconds")
		duration:=ElementParameters.duration " " lang("s #Seconds")
	if (ElementParameters.Unit = "Minutes")
		duration:=ElementParameters.duration " " lang("m #Minutes")
	
	return lang("Sleep") ": " duration
	
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Sleep(Environment, ElementParameters)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Sleep(Environment, ElementParameters)
{
	ElementParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (ElementParameters.Unit="Milliseconds") ;Milliseconds
		tempDuration:=ElementParameters.duration
	else if (ElementParameters.Unit="Seconds") ;Seconds
		tempDuration:=ElementParameters.duration * 1000
	else if (ElementParameters.Unit="Minutes") ;minutes
		tempDuration:=ElementParameters.duration * 60000
	
	functionObject:= x_NewFunctionObject(environment, "Action_Sleep_EndSleep", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	
	SetTimer,% functionObject,-%tempDuration%
	;~ d(functionObject)
	return
	
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Sleep(Environment, ElementParameters)
{
	;~ d(Environment)
	functionObject:=x_getExecutionValue(Environment, "functionObject")
	;~ d(functionObject)
	SetTimer, % functionObject, off
}

;callback function when the sleep timeout ends
Action_Sleep_EndSleep(Environment, ElementParameters="")
{
	;~ d(ElementParameters)
	x_finish(Environment,"normal")
}