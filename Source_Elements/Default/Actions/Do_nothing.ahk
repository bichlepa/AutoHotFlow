
;Name of the element
Element_getName_Action_Do_nothing()
{
	return x_lang("Do nothing")
}

;Category of the element
Element_getCategory_Action_Do_nothing()
{
	return x_lang("Flow_control")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Do_nothing()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Do_nothing()
{
	return "yellow.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Do_nothing()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Do_nothing(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Result")})
	parametersToEdit.push({type: "Radio", id: "executionResult", result: "enum", default: "Normal", choices: [x_lang("Normal"), x_lang("Exception")], enum: ["Normal", "Exception"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Do_nothing(Environment, ElementParameters)
{
	return x_lang("Do nothing") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Do_nothing(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Do_nothing(Environment, ElementParameters)
{
	if (ElementParameters.executionResult != "normal")
	{
		x_finish(Environment, "exception")
		return
	}
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Do_nothing(Environment, ElementParameters)
{
}



