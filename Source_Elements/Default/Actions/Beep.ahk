;Always add this element class name to the global list
x_RegisterElementClass("Action_Beep")

;Element type of the element
Element_getElementType_Action_Beep()
{
	return "action"
}

;Name of the element
Element_getName_Action_Beep()
{
	return x_lang("Beep")
}

;Category of the element
Element_getCategory_Action_Beep()
{
	return x_lang("Sound")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Beep()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Beep()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Beep()
{
	return "Bullhorn.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Beep()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Beep(Environment)
{
	;~ d( x_GetListOfAllVars(environment))
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Frequency in Hz")})
	parametersToEdit.push({type: "edit", id: "frequency", default: 523, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Duration in ms")})
	parametersToEdit.push({type: "edit", id: "duration", default: 150, content: "Expression", WarnIfEmpty: true})
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Beep(Environment, ElementParameters)
{
	return % x_lang("Beep") " - " ElementParameters.frequency " " x_lang("Hz") " " ElementParameters.duration " " x_lang("ms")
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Beep(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Beep(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; make sure, that the values are numbers
	frequency := EvaluatedParameters.frequency
	duration := EvaluatedParameters.duration
	if frequency is not number
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception",x_lang("Frequency is not a number: '%1%'", frequency))
		return
	}
	if duration is not number
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("Frequency is not a number: '%1%'", duration))
		return
	}
	
	; Beep
	SoundBeep, % frequency, % duration
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Beep(Environment, ElementParameters)
{
	
}
