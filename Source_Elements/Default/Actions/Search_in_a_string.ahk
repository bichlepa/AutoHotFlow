;Always add this element class name to the global list
x_RegisterElementClass("Action_Search_in_a_string")

;Element type of the element
Element_getElementType_Action_Search_in_a_string()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Search_in_a_string()
{
	return x_lang("Search_in_a_string")
}

;Category of the element
Element_getCategory_Action_Search_in_a_string()
{
	return x_lang("Text")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Search_in_a_string()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Search_in_a_string()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Search_in_a_string()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Search_in_a_string()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Search_in_a_string(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewPosition", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "Expression", ContentDefault: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Text to search")})
	parametersToEdit.push({type: "Edit", id: "SearchText", default: "World", content: ["String", "Expression"], contentID: "IsExpressionSearchText", ContentDefault: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Which occurence")})
	parametersToEdit.push({type: "Edit", id: "OccurenceNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Start position")})
	parametersToEdit.push({type: "Radio", id: "LeftOrRight", default: "GoRight", choices: [x_lang("Search from left to right"), x_lang("Search from right to left")], result: "enum", enum: ["GoRight", "GoLeft"]})
	parametersToEdit.push({type: "Edit", id: "Offset", default: 1, content: "PositiveInteger", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Case sensitivity")})
	parametersToEdit.push({type: "Radio", id: "CaseSensitive", default: "CaseInsensitive", choices: [x_lang("Case insensitive"), x_lang("Case sensitive")], result: "enum", enum: ["CaseInsensitive", "CaseSensitive"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Search_in_a_string(Environment, ElementParameters)
{
	return x_lang("Search_in_a_string") " - " ElementParameters.Varname " - " ElementParameters.VarValue " - " ElementParameters.SearchText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Search_in_a_string(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Search_in_a_string(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; do we serach from right to left?
	if (EvaluatedParameters.LeftOrRight = "GoLeft")
	{
		; calculate index, so we can search from right to left
		EvaluatedParameters.Offset := 1 - EvaluatedParameters.Offset
	}

	; search for the string
	Result := instr(EvaluatedParameters.VarValue, EvaluatedParameters.SearchText, (EvaluatedParameters.CaseSensitive = "CaseSensitive"), EvaluatedParameters.Offset, EvaluatedParameters.OccurenceNumber)

	; check for errors
	if (Result = 0)
	{
		; nothing found
		x_SetVariable(Environment, EvaluatedParameters.Varname, "") 
		x_finish(Environment, "exception", x_lang("Searched text was not found")) 
		return
	}

	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Result) 
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Search_in_a_string(Environment, ElementParameters)
{
}






