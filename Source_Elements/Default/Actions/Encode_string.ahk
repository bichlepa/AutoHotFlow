
;Name of the element
Element_getName_Action_Encode_string()
{
	return x_lang("Encode string")
}

;Category of the element
Element_getCategory_Action_Encode_string()
{
	return x_lang("Text")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Encode_string()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Encode_string()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Encode_string()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Encode_string(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "EncodedString", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Output format")})
	parametersToEdit.push({type: "Radio", id: "outputEncodingFormat", result: "enum", default: "URL", choices: [x_lang("URL")], enum: ["URL"]})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Encode_string(Environment, ElementParameters)
{
	return x_lang("Encode string") " - " ElementParameters.Varname " - " ElementParameters.VarValue  " - " ElementParameters.outputEncodingFormat
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Encode_string(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Encode_string(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	switch EvaluatedParameters.outputEncodingFormat
	{
		case "URL":
			result := x_UriEncode(EvaluatedParameters.VarValue)
		default:
			x_finish(Environment, "exception", x_lang("Unknown output encoding format: %1%", outputEncodingFormat))
			return
	}
	

	; set output variable
	x_setVariable(Environment, EvaluatedParameters.Varname, result)

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Encode_string(Environment, ElementParameters)
{
}



