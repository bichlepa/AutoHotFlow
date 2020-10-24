;Always add this element class name to the global list
x_RegisterElementClass("Action_Trace_Point")

;Element type of the element
Element_getElementType_Action_Trace_Point()
{
	return "action"
}

;Name of the element
Element_getName_Action_Trace_Point()
{
	return lang("Trace_Point")
}

;Category of the element
Element_getCategory_Action_Trace_Point()
{
	return lang("Debugging")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Trace_Point()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Trace_Point()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Trace_Point()
{
	return "Source_elements\default\icons\New variable.png"
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
	parametersToEdit.push({type: "Label", label: lang("ID")})
	parametersToEdit.push({type: "Edit", id: "ID", content: "String",  default: x_randomPhrase()})
	parametersToEdit.push({type: "Label", label: lang("Log message")})
	parametersToEdit.push({type: "Edit", id: "LogMessage", default: "", content: "String", WarnIfEmpty: false})
	parametersToEdit.push({type: "Label", label: lang("Stop condition")})
	parametersToEdit.push({type: "Edit", id: "StopCondition", default: "", content: "Expression", WarnIfEmpty: false})
	

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Trace_Point(Environment, ElementParameters)
{
	global
	return % lang("Trace_Point") " - " ElementParameters.ID 
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Trace_Point(Environment, ElementParameters)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Trace_Point(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	ID := x_replaceVariables(Environment, ElementParameters.ID)
	LogMessage := x_replaceVariables(Environment, ElementParameters.LogMessage)
	
	evRes := x_EvaluateExpression(Environment, ElementParameters.StopCondition)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.StopCondition) "`n`n" evRes.error) 
		return
	}
	else
	{
		StopCondition:=evRes.result
	}
	
	elementID:=x_GetMyElementID(Environment)
	
	x_log(Environment, LogMessage, 0)
	passed_Tracepoints := x_GetVariable(Environment, "passed_Tracepoints", true)
	if not IsObject(passed_Tracepoints)
	{
		passed_Tracepoints:=Object()
	}
	passed_Tracepoints.push(ID " (" elementID ")")
	

	x_SetVariable(Environment, "passed_Tracepoints", passed_Tracepoints,, true)
	
	if (stopcondition)
	{
		x_finish(Environment, "exception", lang("Stopping execution because stop Condition " ElementParameters.StopCondition " is not false"))
		x_InstanceStop(Environment)
	}
	else
	{
		x_finish(Environment, "normal")
	}
	
	;Always call v_finish() before return
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Trace_Point(Environment, ElementParameters)
{
	
}

