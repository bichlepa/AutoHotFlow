;Always add this element class name to the global list
AllElementClasses.push("Action_Set_Lock_Key")

;Element type of the element
Element_getElementType_Action_Set_Lock_Key()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_Lock_Key()
{
	return lang("Set_Lock_Key")
}

;Category of the element
Element_getCategory_Action_Set_Lock_Key()
{
	return lang("User_simulation")
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

;Icon path which will be shown in the background of the element
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
	
	parametersToEdit.push({type: "Label", label: lang("Which lock key")})
	parametersToEdit.push({type: "Radio", id: "WhichKey", default: 1, choices: [lang("Caps lock"), lang("Num lock"), lang("Scroll lock")], result: "enum", enum: ["CapsLock", "NumLock", "ScrollLock"]})
	parametersToEdit.push({type: "Label", label: lang("Status to set")})
	parametersToEdit.push({type: "Radio", id: "Status", default: 1, choices: [lang("On"), lang("Off"), lang("Toggle"), lang("Always on"), lang("Always off")], result: "enum", enum: ["On", "Off", "Toggle", "AlwaysOn", "AlwaysOff"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Lock_Key(Environment, ElementParameters)
{
	return lang("Set_Lock_Key") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Lock_Key(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Lock_Key(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (ElementParameters.WhichKey="CapsLock")
	{
		if (ElementParameters.Status="Toggle")
		{
			SetStoreCapslockMode, Off 
			SendInput {CapsLock}
			SetStoreCapslockMode, On
		}
		else
		{
			SetCapsLockState, % ElementParameters.Status
		}
	}
	else if (ElementParameters.WhichKey="NumLock") ;Num lock
	{
		if (ElementParameters.Status="Toggle")
		{
			SendInput {NumLock}
		}
		else
		{
			SetNumLockState, % ElementParameters.Status
		}
	}
	else if (ElementParameters.WhichKey="ScrollLock") ;Scroll Lock
	{
		
		if (ElementParameters.Status="Toggle")
		{
			SendInput {ScrollLock}
		}
		else
		{
			SetScrollLockState, % ElementParameters.Status
		}
	}
	
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Lock_Key(Environment, ElementParameters)
{
}






