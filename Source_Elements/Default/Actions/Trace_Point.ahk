;Always add this element class name to the global list
AllElementClasses.push("Action_Trace_Point")

Element_getPackage_Action_Trace_Point()
{
	return "default"
}

Element_getElementType_Action_Trace_Point()
{
	return "action"
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

Element_getParameters_Action_Trace_Point()
{
	return ["ID", "LogMessage", "StopCondition"]
}

Element_getParametrizationDetails_Action_Trace_Point()
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

Element_run_Action_Trace_Point(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	ID := x_replaceVariables(Environment, ElementParameters.ID)
	LogMessage := x_replaceVariables(Environment, ElementParameters.LogMessage)
	StopCondition := x_evaluateExpression(Environment, ElementParameters.StopCondition)
	elementID:=x_GetMyElementID(Environment)
	
	x_log(Environment, LogMessage, 0)
	passed_Tracepoints := x_GetVariable(Environment, "passed_Tracepoints", "hidden")
	if not IsObject(passed_Tracepoints)
	{
		passed_Tracepoints:=Object()
	}
	passed_Tracepoints.push(ID " (" elementID ")")
	

	x_SetVariable(Environment, "passed_Tracepoints", passed_Tracepoints,, "hidden")
	
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

Element_GenerateName_Action_Trace_Point(Environment, ElementParameters)
{
	global
	return % lang("Trace_Point") " - " ElementParameters.ID 
	
}