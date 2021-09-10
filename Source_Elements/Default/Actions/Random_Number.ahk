;Always add this element class name to the global list
x_RegisterElementClass("Action_Random_number")

;Element type of the element
Element_getElementType_Action_Random_number()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Random_number()
{
	return x_lang("Random_number")
}

;Category of the element
Element_getCategory_Action_Random_number()
{
	return x_lang("Variable") "|" x_lang("Maths")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Random_number()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Random_number()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Random_number()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Random_number()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Random_number(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Minimum value")})
	parametersToEdit.push({type: "Edit", id: "MinValue", default: 0, content: "Number", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Maximum value")})
	parametersToEdit.push({type: "Edit", id: "MaxValue", default: 100, content: "Number", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Random_number(Environment, ElementParameters)
{
	return x_lang("Random_number") " - " ElementParameters.Varname " - " ElementParameters.MinValue "-" ElementParameters.MaxValue
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Random_number(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Random_number(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; generate random number
	Random, result, EvaluatedParameters.MinValue, % EvaluatedParameters.MaxValue
	
	; write output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, result)
	
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Random_number(Environment, ElementParameters)
{
}






