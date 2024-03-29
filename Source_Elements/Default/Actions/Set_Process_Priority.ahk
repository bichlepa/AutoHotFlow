﻿
;Name of the element
Element_getName_Action_Set_Process_Priority()
{
	return x_lang("Set_Process_Priority")
}

;Category of the element
Element_getCategory_Action_Set_Process_Priority()
{
	return x_lang("Process")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Process_Priority()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Set_Process_Priority()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Process_Priority()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Process_Priority(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Process name or ID")})
	parametersToEdit.push({type: "Edit", id: "ProcessName", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Priority")})
	parametersToEdit.push({type: "Radio", id: "Priority", default: "Normal", choices: [x_lang("Low"), x_lang("Below normal"), x_lang("Normal"), x_lang("Above normal"), x_lang("High"), x_lang("Realtime")], result: "enum", enum: ["Low", "BelowNormal", "Normal", "AboveNormal", "High", "Realtime"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Process_Priority(Environment, ElementParameters)
{
	switch (ElementParameters.Priority)
	{
		case "Low":
		PriorityString := x_lang("Low")
		case "BelowNormal":
		PriorityString := x_lang("Below normal")
		case "Normal":
		PriorityString := x_lang("Normal")
		case "AboveNormal":
		PriorityString := x_lang("Above normal")
		case "High":
		PriorityString := x_lang("High")
		case "Realtime":
		PriorityString := x_lang("Realtime")
	}

	return x_lang("Set_Process_Priority") " - " ElementParameters.ProcessName " - " PriorityString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Process_Priority(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Process_Priority(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; set process priority
	Process, Priority, % ElementParameters.ProcessName, % ElementParameters.Priority

	; check for errors
	if (ErrorLevel = 0)
	{
		; an error occured. check whether process exists
		Process, exist, % EvaluatedParameters.ProcessName
		if (ErrorLevel = 0)
		{
			x_finish(Environment, "exception", x_lang("Process '%1%' does not exist", EvaluatedParameters.ProcessName))
		}
		else
		{
			; set PID of process to a thread variable
			x_SetVariable(Environment, "A_Pid", errorlevel, "thread")

			x_finish(Environment, "exception", x_lang("Priority of process '%1%' could not be changed", EvaluatedParameters.ProcessName))
		}
		return
	}

	; set PID of process to a thread variable
	x_SetVariable(Environment, "A_Pid", errorlevel, "thread")

	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Process_Priority(Environment, ElementParameters)
{
}






