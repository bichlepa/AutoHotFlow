;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_Lock_Key")

;Element type of the element
Element_getElementType_Action_Set_Lock_Key()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_Lock_Key()
{
	return x_lang("Set_Lock_Key")
}

;Category of the element
Element_getCategory_Action_Set_Lock_Key()
{
	return x_lang("User_simulation")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_Lock_Key()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Lock_Key()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Set_Lock_Key()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Lock_Key()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Lock_Key(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Which lock key")})
	parametersToEdit.push({type: "Radio", id: "WhichKey", default: "CapsLock", choices: [x_lang("Caps lock"), x_lang("Num lock"), x_lang("Scroll lock")], result: "enum", enum: ["CapsLock", "NumLock", "ScrollLock"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Status to set")})
	parametersToEdit.push({type: "Radio", id: "Status", default: "On", choices: [x_lang("On"), x_lang("Off"), x_lang("Toggle"), x_lang("Always on"), x_lang("Always off")], result: "enum", enum: ["On", "Off", "Toggle", "AlwaysOn", "AlwaysOff"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Lock_Key(Environment, ElementParameters)
{
	switch (ElementParameters.WhichKey)
	{
		case "CapsLock":
		whichKeyText := x_lang("Caps lock")
		case "NumLock":
		whichKeyText := x_lang("Num lock")
		case "ScrollLock":
		whichKeyText := x_lang("Scroll lock")
	}
	switch (ElementParameters.Status)
	{
		case "On":
		statusText := x_lang("On")
		case "Off":
		statusText := x_lang("Off")
		case "Toggle":
		statusText := x_lang("Toggle")
		case "AlwaysOn":
		statusText := x_lang("Always on")
		case "AlwaysOff":
		statusText := x_lang("Always off")
	}
	return x_lang("Set_Lock_Key") " - " whichKeyText " - " statusText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Lock_Key(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Lock_Key(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (EvaluatedParameters.WhichKey = "CapsLock")
	{
		; caps lock should be set

		if (EvaluatedParameters.Status = "Toggle")
		{
			; toggle caps lock
			SetCapsLockState, % not GetKeyState("CapsLock", "T")
		}
		else
		{
			; for all other options we can use the enum value directly
			SetCapsLockState, % EvaluatedParameters.Status
		}
	}
	else if (EvaluatedParameters.WhichKey = "NumLock")
	{
		; num lock should be set

		if (EvaluatedParameters.Status = "Toggle")
		{
			; toggle num lock
			SetNumLockState, % not GetKeyState("NumLock", "T")
		}
		else
		{
			; for all other options we can use the enum value directly
			SetNumLockState, % EvaluatedParameters.Status
		}
	}
	else if (EvaluatedParameters.WhichKey = "ScrollLock") ;Scroll Lock
	{
		; scroll lock should be set
		
		if (EvaluatedParameters.Status="Toggle")
		{
			; toggle scroll lock
			SetScrollLockState, % not GetKeyState("ScrollLock", "T")
		}
		else
		{
			; for all other options we can use the enum value directly
			SetScrollLockState, % EvaluatedParameters.Status
		}
	}
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Lock_Key(Environment, ElementParameters)
{
}






