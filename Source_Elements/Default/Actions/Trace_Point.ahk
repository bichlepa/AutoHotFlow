;Always add this element class name to the global list
x_RegisterElementClass("Action_Trace_Point")

Element_getPackage_Action_Trace_Point()
{
	return "default"
}

Element_getElementType_Action_Trace_Point()
{
	return "action"
}

Element_getElementLevel_Action_Trace_Point()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

Element_getName_Action_Trace_Point()
{
	return lang("Trace_Point")
}

Element_getIconPath_Action_Trace_Point()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Trace_Point()
{
	return lang("Debugging")
}

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

Element_GenerateName_Action_Trace_Point(Environment, ElementParameters)
{
	global
	return % lang("Trace_Point") " - " ElementParameters.ID 
	
}

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