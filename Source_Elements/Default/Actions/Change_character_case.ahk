﻿
;Name of the element
Element_getName_Action_Change_character_case()
{
	return x_lang("Change_character_case")
}

;Category of the element
Element_getCategory_Action_Change_character_case()
{
	return x_lang("Text")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Change_character_case()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Change_character_case()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Change_character_case()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Change_character_case(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Which case #character case")})
	parametersToEdit.push({type: "Radio", id: "CharCase", default: "upper", result: "enum", choices: [x_lang("Uppercase"), x_lang("Lowercase"), x_lang("First character of a word is uppercase")], enum: ["upper", "lower", "firstUp"]})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Change_character_case(Environment, ElementParameters)
{
	switch (ElementParameters.CharCase)
	{
		case "upper":
		charCaseText := x_lang("Uppercase")
		case "lower":
		charCaseText := x_lang("Lowercase")
		case "firstUp":
		charCaseText := x_lang("First character uppercase")
	}

	return x_lang("Change_character_case") " - " charCaseText " - " ElementParameters.Varname " - " ElementParameters.VarValue
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Change_character_case(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Change_character_case(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; change character case as desired
	VarValue := EvaluatedParameters.VarValue
	switch (EvaluatedParameters.CharCase)
	{
		case "upper":
		StringUpper, result, VarValue
		case "lower":
		StringLower, result, VarValue
		case "firstUp":
		StringUpper, result, VarValue, T ;First character of a word is uppercase
	}

	; write variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, result)
	
	;Always call v_finish() before return
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Change_character_case(Environment, ElementParameters)
{
	
}





