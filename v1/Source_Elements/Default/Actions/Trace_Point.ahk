
;Name of the element
Element_getName_Action_Trace_Point()
{
	return x_lang("Trace_Point")
}

;Category of the element
Element_getCategory_Action_Trace_Point()
{
	return x_lang("Debugging")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Trace_Point()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Trace_Point()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Trace_Point()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Trace_Point(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("ID")})
	parametersToEdit.push({type: "Edit", id: "ID", content: "rawstring",  default: "Tracepoint " x_randomPhrase()})
	parametersToEdit.push({type: "Label", label: x_lang("Log message")})
	parametersToEdit.push({type: "Edit", id: "LogMessage", default: "", content: "String", WarnIfEmpty: false})
	parametersToEdit.push({type: "Label", label: x_lang("Stop condition")})
	parametersToEdit.push({type: "Edit", id: "StopCondition", default: "", content: "Expression", WarnIfEmpty: false})

	; request that the result of this function is never cached (because we want a unique random phrase for each element)
	parametersToEdit.updateOnEdit := true
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Trace_Point(Environment, ElementParameters)
{
	if (ElementParameters.StopCondition)
		textStopCondition := " - " x_lang("With stop condition")
	return % x_lang("Trace_Point") " - " ElementParameters.ID textStopCondition
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Trace_Point(Environment, ElementParameters, staticValues)
{	
	; generate a random ID
	if (ElementParameters.ID = "ṳᦵṩḗ╥")
		x_Par_SetValue("ID", "Tracepoint " x_randomPhrase())
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Trace_Point(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; write the log message
	if (EvaluatedParameters.LogMessage)
	{
		x_log(Environment, EvaluatedParameters.LogMessage, 0)
	}

	; get own element ID
	elementID := x_GetMyElementID(Environment)
	
	; get hidden variable "passed_Tracepoints" and write there the current trace point
	; include the element ID to make the trace point unique
	passed_Tracepoints := x_GetVariable(Environment, "passed_Tracepoints", true)
	if not IsObject(passed_Tracepoints)
	{
		passed_Tracepoints := Object()
	}
	passed_Tracepoints.push(EvaluatedParameters.ID " (" elementID ")")
	x_SetVariable(Environment, "passed_Tracepoints", passed_Tracepoints,, true)
	
	; Check the evaluated stop condition
	if (EvaluatedParameters.stopcondition)
	{
		; stop condition is true. Finish element and stop the execution
		x_finish(Environment, "exception", x_lang("Stopping execution because stop Condition '%1%' is not false", EvaluatedParameters.StopCondition))
		x_InstanceStop(Environment)
	}
	else
	{
		; stop condition is not true. finish
		x_finish(Environment, "normal")
	}
	
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Trace_Point(Environment, ElementParameters)
{
	; nothing to do
}

