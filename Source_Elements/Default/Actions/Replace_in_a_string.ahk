;Always add this element class name to the global list
x_RegisterElementClass("Action_replace_in_a_string")

;Element type of the element
Element_getElementType_Action_replace_in_a_string()
{
	return "Action"
}

;Name of the element
Element_getName_Action_replace_in_a_string()
{
	return x_lang("Replace in a string")
}

;Category of the element
Element_getCategory_Action_replace_in_a_string()
{
	return x_lang("Text")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_replace_in_a_string()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_replace_in_a_string()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_replace_in_a_string()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_replace_in_a_string()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_replace_in_a_string(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Text to search")})
	parametersToEdit.push({type: "Edit", id: "SearchText", default: "World", content: "String", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Replace by")})
	parametersToEdit.push({type: "Edit", id: "ReplaceText", default: "%a_username%", content: "String", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Number of replacements")})
	parametersToEdit.push({type: "Radio", id: "ReplaceAll", default: "first", choices: [lang("Replace only the first occurence"), lang("Replace all occurences")], result: "enum", enum: ["first", "all"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Case sensitivity")})
	parametersToEdit.push({type: "Radio", id: "CaseSensitive", default: "CaseInsensitive", choices: [x_lang("Case insensitive"), x_lang("Case sensitive")], result: "enum", enum: ["CaseInsensitive", "CaseSensitive"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_replace_in_a_string(Environment, ElementParameters)
{
	return x_lang("Replace in a string") " - " ElementParameters.Varname " - " ElementParameters.VarValue " - " ElementParameters.SearchText " - " ElementParameters.ReplaceText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_replace_in_a_string(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_replace_in_a_string(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; set string case sense
	CaseSensitive := (EvaluatedParameters.CaseSensitive = "CaseSensitive") ? "on" : "off"
	StringCaseSense, %CaseSensitive%

	; prepare limit parameter
	if (EvaluatedParameters.ReplaceAll = "first")
	{
		limit := 1
	}
	Else
	{
		limit := -1
	}

	; replace text
	Result := StrReplace(EvaluatedParameters.VarValue, EvaluatedParameters.SearchText, EvaluatedParameters.ReplaceText, OutputVarCount, limit)
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Result)

	; set number of replacements as thread variable
	x_SetVariable(Environment, "a_numberOfReplacements", OutputVarCount, "Thread")

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_replace_in_a_string(Environment, ElementParameters)
{
}






