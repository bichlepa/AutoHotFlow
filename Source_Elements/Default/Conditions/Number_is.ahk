;Always add this element class name to the global list
x_RegisterElementClass("Condition_NumberIs")

;Element type of the element
Element_getElementType_Condition_NumberIs()
{
	return "condition"
}

;Name of the element
Element_getName_Condition_NumberIs()
{
	return x_lang("Number is")
}

;Category of the element
Element_getCategory_Condition_NumberIs()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_NumberIs()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_NumberIs()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_NumberIs()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_NumberIs()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_NumberIs(Environment)
{
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("Input number")})
	parametersToEdit.push({type: "Edit", id: "expression", default: "5.0001", content: "Number", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Expected number")})
	parametersToEdit.push({type: "Edit", id: "expectedNumber", default: "5", content: "Number", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Maximum difference")})

	parametersToEdit.push({type: "Label", label: x_lang("Absolute difference"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "absoluteDeviation", default: "0", content: "PositiveNumber"})

	parametersToEdit.push({type: "Label", label: x_lang("Relative difference"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "relativeDeviation", default: "0.01", content: "PositiveNumber"})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_NumberIs(Environment, ElementParameters)
{
	return % x_lang("Number is") " - " ElementParameters.expression " - " ElementParameters.expectedNumber
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_NumberIs(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_NumberIs(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
	}

	; NumberIs was successfully evaluated. Check the result and convert it to a boolean result.

	deviation := 0

	; calculate the allowed deviation
	if (EvaluatedParameters.absoluteDeviation)
	{
		deviation += EvaluatedParameters.absoluteDeviation
	}
	if (EvaluatedParameters.relativeDeviation)
	{
		deviation += abs(EvaluatedParameters.expectedNumber) * EvaluatedParameters.relativeDeviation
	}

	; compare the input number with the expected number and allow the deviation
	if ((EvaluatedParameters.expression >= (EvaluatedParameters.expectedNumber - deviation)) 
		and (EvaluatedParameters.expression <= (EvaluatedParameters.expectedNumber + deviation)))
	{
		return x_finish(Environment, "yes")
	}
	else
	{
		return x_finish(Environment, "no")
	}
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_NumberIs(Environment, ElementParameters)
{

}