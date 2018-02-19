;Always add this element class name to the global list
AllElementClasses.push("Trigger_Process_starts")

;Element type of the element
Element_getElementType_Trigger_Process_starts()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Process_starts()
{
	return lang("Process_starts")
}

;Category of the element
Element_getCategory_Trigger_Process_starts()
{
	return lang("Process")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Process_starts()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Process_starts()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Process_starts()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Process_starts()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Process_starts(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Process name or ID")})
	parametersToEdit.push({type: "Edit", id: "ProcessName", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Process_starts(Environment, ElementParameters)
{
	return lang("Process_starts") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Process_starts(Environment, ElementParameters)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_Process_starts(Environment, ElementParameters)
{
	
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	
	inputVars:={ProcessName: EvaluatedParameters.ProcessName} ;Variables which will be available in the external scriptExample
	outputVars:=["processID"]
	code =
	( ` , LTrim %
		loop
		{
			process,wait,%ProcessName%
			x_trigger()
			process,waitclose,%ProcessName%
		}
	)
	
	x_TriggerInNewAHKThread(Environment, code, inputVars, outputVars)
	x_enabled(Environment, "normal")
}


;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Process_starts(Environment, ElementParameters)
{
	exportedValues:=x_TriggerInNewAHKThread_GetExportedValues(Environment)
	x_SetVariable(Environment,"a_pid",exportedValues.processID,"Thread")
}

;Called when the trigger should be disabled.
Element_disable_Trigger_Process_starts(Environment, ElementParameters)
{
	functionObject := x_GetExecutionValue(environment, "functionObject")
	SetTimer, % functionObject, delete
	x_disabled(Environment, "normal")
}



