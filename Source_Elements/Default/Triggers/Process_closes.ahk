;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Process_Closes")

;Element type of the element
Element_getElementType_Trigger_Process_Closes()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Process_Closes()
{
	return x_lang("Process_Closes")
}

;Category of the element
Element_getCategory_Trigger_Process_Closes()
{
	return x_lang("Process")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Process_Closes()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Process_Closes()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Trigger_Process_Closes()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Process_Closes()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Process_Closes(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Process name or ID")})
	parametersToEdit.push({type: "Edit", id: "ProcessName", content: "String"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Label", label: x_lang("Check interval (ms)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "interval", content: "Number", default: 1000, WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Process_Closes(Environment, ElementParameters)
{
	return x_lang("Process_Closes") "`n" ElementParameters.ProcessName
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Process_Closes(Environment, ElementParameters, staticValues)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_Process_Closes(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check interval
	if (not (EvaluatedParameters.interval > 0))
	{
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "interval", tempinterval)) 
		return
	}

	; We will set a timer which regularely checks the processes
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Process_Closes_TimerLabel", EvaluatedParameters)
	x_SetTriggerValue(Environment, "functionObject", functionObject)

	; make the first call immediately
	%functionObject%(true)

	; enable the timer
	SetTimer, % functionObject, % EvaluatedParameters.interval

	; finish and return true
	x_enabled(Environment, "normal")
	return true
}


;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Process_Closes(Environment, ElementParameters, TriggerData)
{
	x_SetVariable(Environment, "A_ProcessID", TriggerData.processID, "Thread")
	x_SetVariable(Environment, "A_ProcessName", TriggerData.processName, "Thread")
}

;Called when the trigger should be disabled.
Element_disable_Trigger_Process_Closes(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal")
}


; function which will be regularey called
Trigger_Process_Closes_TimerLabel(Environment, parameters, fistCall = false)
{
	if (fistCall)
	{
		x_log(Environment, "ProcessClosesTimerLabelFirstCall")
		; on first call, we need to create an initial list of processes
		parameters.currentProcesses := getProcessList(parameters.ProcessName)
	}

	; get a list of all matching processes
	currentProcesses := getProcessList(parameters.ProcessName)

	; check whether some elements are missing now
	for oneProcessID, oneProcessName in parameters.currentProcesses
	{
		if (not currentProcesses.hasKey(oneProcessID))
		{
			x_log(Environment, "ProcessClosesTimerLabelTriggering. Process ID:" oneProcessID)
			
			; a process is missing now. Call the trigger
			x_trigger(Environment, {processID: oneProcessID, processName: oneProcessName})
		}
	}
	; the result has changed. Save the changed value.
	parameters.currentProcesses := currentProcesses
}


