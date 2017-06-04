;Always add this element class name to the global list
AllElementClasses.push("Action_Beep")

Element_getPackage_Action_Beep()
{
	return "default"
}

Element_getElementType_Action_Beep()
{
	return "action"
}

Element_getName_Action_Beep()
{
	return lang("Beep")
}

Element_getIconPath_Action_Beep()
{
	return "Source_elements\default\icons\Bullhorn.png"
}

Element_getCategory_Action_Beep()
{
	return lang("Sound")
}

Element_getParameters_Action_Beep()
{
	return ["frequency", "duration"]
}

Element_getParametrizationDetails_Action_Beep(Environment)
{
	;~ d( x_GetListOfAllVars(environment))
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Frequency in Hz")})
	parametersToEdit.push({type: "edit", id: "frequency", default: 523, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Duration in ms")})
	parametersToEdit.push({type: "edit", id: "duration", default: 150, content: "Expression", WarnIfEmpty: true})
	return parametersToEdit
}

Element_GenerateName_Action_Beep(Environment, ElementParameters)
{
	return % lang("Beep") " - " ElementParameters.frequency " " lang("Hz") " " ElementParameters.duration " " lang("ms")
}

Element_run_Action_Beep(Environment, ElementParameters)
{
	frequencyObj:=x_evaluateExpression(Environment,ElementParameters.frequency)
	
	if (frequencyObj.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.frequency) "`n`n" frequencyObj.error) 
		return
	}
	frequency:=frequencyObj.result
	
	durationObj:=x_evaluateExpression(Environment,ElementParameters.duration)
	if (durationObj.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.duration)) "`n`n" durationObj.error
		return
	}
	duration:=durationObj.result
	
	if frequency is not number
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception",lang("Frequency is not a number: '%1%'", frequency))
		return
	}
	if duration is not number
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("Frequency is not a number: '%1%'", duration))
		return
	}
	
	;Do the action
	SoundBeep,% frequency,% duration
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}
