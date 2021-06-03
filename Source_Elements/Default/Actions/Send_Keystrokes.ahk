;Always add this element class name to the global list
x_RegisterElementClass("Action_Send_keystrokes")

;Element type of the element
Element_getElementType_Action_Send_keystrokes()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Send_keystrokes()
{
	return x_lang("Send_keystrokes")
}

;Category of the element
Element_getCategory_Action_Send_keystrokes()
{
	return x_lang("User_simulation")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Send_keystrokes()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Send_keystrokes()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Send_keystrokes()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Send_keystrokes()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Send_keystrokes(Environment)
{
	parametersToEdit:=Object()
	
	
	parametersToEdit.push({type: "Label", label: x_lang("Keys_or_text_to_send")})
	parametersToEdit.push({type: "Checkbox", id: "RawMode", default: 0, label: x_lang("Raw mode")})
	parametersToEdit.push({type: "Edit", id: "KeysToSend", content: ["RawString", "String"], contentID: "KeysToSendContentType", ContentDefault: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Send mode")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, choices: [x_lang("Input mode"), x_lang("Event mode"), x_lang("Play mode")], result: "enum", enum: ["Input", "Event", "Play"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Send_keystrokes(Environment, ElementParameters)
{
	return x_lang("Send_keystrokes") " - " ElementParameters.KeysToSend
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Send_keystrokes(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Send_keystrokes(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; decide whether we will send in raw mode or not
	if (EvaluatedParameters.RawMode)
		rawTextOption := "{raw}"
	else
		rawTextOption :=

	; set send mode
	SendMode, % EvaluatedParameters.sendmode
	
	; send keystrokes
	Send, % rawTextOption EvaluatedParameters.KeysToSend
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Send_keystrokes(Environment, ElementParameters)
{
}






