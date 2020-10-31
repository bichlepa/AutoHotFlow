;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Clipboard_Changes")

;Element type of the element
Element_getElementType_Trigger_Clipboard_Changes()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Clipboard_Changes()
{
	return x_lang("Clipboard_Changes")
}

;Category of the element
Element_getCategory_Trigger_Clipboard_Changes()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Clipboard_Changes()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Clipboard_Changes()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Clipboard_Changes()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Clipboard_Changes()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Clipboard_Changes(Environment)
{
	parametersToEdit:=Object()
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Clipboard_Changes(Environment, ElementParameters)
{
	return x_lang("Clipboard_Changes") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Clipboard_Changes(Environment, ElementParameters)
{	
	
}




;Called when the trigger is activated
Element_enable_Trigger_Clipboard_Changes(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Clipboard_Changes_Trigger", EvaluatedParameters)
	x_SetTriggerValue(environment, "functionObject", functionObject)
	
	; call function object every time the clipboard changes
	OnClipboardChange(functionObject)
	
	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Function which triggers the flow
Trigger_Clipboard_Changes_Trigger(environment, EvaluatedParameters)
{
	x_trigger(Environment)
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Clipboard_Changes(Environment, ElementParameters)
{
}

;Called when the trigger should be disabled.
Element_disable_Trigger_Clipboard_Changes(Environment, ElementParameters)
{
	; get the function object and disable the call on clipboard change
	functionObject := x_getTriggerValue(Environment, "functionObject")
	OnClipboardChange(functionObject, 0)

	; finish
	x_disabled(Environment, "normal")
}



