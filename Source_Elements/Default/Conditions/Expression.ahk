
;Name of the element
Element_getName_Condition_Expression()
{
	return x_lang("Expression")
}

;Category of the element
Element_getCategory_Condition_Expression()
{
	return x_lang("Variable")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Expression()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Condition_Expression()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Expression()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Expression(Environment)
{
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("Expression")})
	parametersToEdit.push({type: "multilineEdit", id: "Expression", content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Expression(Environment, ElementParameters)
{
	return % x_lang("Expression") " - " ElementParameters.expression
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Expression(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Expression(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
	}

	; Expression was successfully evaluated. Check the result and convert it to a boolean result.
	if (EvaluatedParameters.expression)
		return x_finish(Environment, "yes")
	else
		return x_finish(Environment, "no")
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Expression(Environment, ElementParameters)
{

}