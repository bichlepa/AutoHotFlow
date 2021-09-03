;Always add this element class name to the global list
x_RegisterElementClass("Condition_String_Contains_Text")

;Element type of the element
Element_getElementType_Condition_String_Contains_Text()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_String_Contains_Text()
{
	return x_lang("String_Contains_Text")
}

;Category of the element
Element_getCategory_Condition_String_Contains_Text()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_String_Contains_Text()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_String_Contains_Text()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_String_Contains_Text()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_String_Contains_Text()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_String_Contains_Text(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "Expression", ContentDefault: "String", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Text to search")})
	parametersToEdit.push({type: "Edit", id: "SearchText", default: "World", content: ["String", "Expression"], contentID: "IsExpressionSearchText", ContentDefault: "String", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Search text position")})
	parametersToEdit.push({type: "Radio", id: "WhereToBegin", default: 3, choices: [x_lang("Starts with"), x_lang("Ends with"), x_lang("Contains anywhere")], result: "enum", enum: ["Start", "End", "Anywhere"]})

	parametersToEdit.push({type: "Label", label: x_lang("Case sensitivity")})
	parametersToEdit.push({type: "Radio", id: "CaseSensitive", default: 1, choices: [x_lang("Case insensitive"), x_lang("Case sensitive")], result: "enum", enum: ["CaseInsensitive", "CaseSensitive"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_String_Contains_Text(Environment, ElementParameters)
{
	if (ElementParameters.WhereToBegin = "Start")
		text := x_lang("'%1%' starts with '%2%'", ElementParameters.VarValue, ElementParameters.SearchText)
	if (ElementParameters.WhereToBegin = "End")
		text := x_lang("'%1%' starts with '%2%'", ElementParameters.VarValue, ElementParameters.SearchText)
	if (ElementParameters.WhereToBegin = "Anywhere")
		text := x_lang("'%1%' contains '%2%'", ElementParameters.VarValue, ElementParameters.SearchText)

	if (ElementParameters.CaseSensitive = "CaseInsensitive")
		caseText := x_lang("Case insensitive")
	if (ElementParameters.CaseSensitive = "CaseSensitive")
		caseText := x_lang("Case sensitive")

	return x_lang("String_Contains_Text") " - "  text " - " caseText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_String_Contains_Text(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_String_Contains_Text(Environment, ElementParameters)
{
	; evaluate some parameters
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; Look at parameter WhereToBegin
	if (EvaluatedParameters.WhereToBegin = "Anywhere")
	{
		; we will search anywhere for the string
		CaseSensitive := (EvaluatedParameters.CaseSensitive = "CaseSensitive")
		result := instr(EvaluatedParameters.VarValue, EvaluatedParameters.SearchText, CaseSensitive)

		; set case sensitivity
		if (result)
		{
			x_finish(Environment, "yes")
		}
		else
		{
			x_finish(Environment, "no")
		}
	}
	else if (EvaluatedParameters.WhereToBegin = "Start")
	{
		; we will check, whether the string starts with the search string

		; extract as many characters as the search string long is (from start)
		StringLeft, temp, % EvaluatedParameters.VarValue, strlen(EvaluatedParameters.SearchText)

		if (EvaluatedParameters.CaseSensitive = "CaseInsensitive")
		{
			; compare cese insensitive
			if (temp = EvaluatedParameters.SearchText)
				x_finish(Environment, "yes")
			else
				x_finish(Environment, "no")
		}
		else
		{
			; compare cese sensitive
			if (temp == EvaluatedParameters.SearchText)
				x_finish(Environment, "yes")
			else
				x_finish(Environment, "no")
		}
	}
	else if (EvaluatedParameters.WhereToBegin = "End") ;Ends with
	{
		; we will check, whether the string ends with the search string
		
		; extract as many characters as the search string long is (from the end)
		StringRight, temp, % EvaluatedParameters.VarValue, strlen(EvaluatedParameters.SearchText)
		
		if (EvaluatedParameters.CaseSensitive = "CaseInsensitive")
		{
			; compare cese insensitive
			if (temp = EvaluatedParameters.SearchText)
				x_finish(Environment, "yes")
			else
				x_finish(Environment, "no")
		}
		else
		{
			; compare cese sensitive
			if (temp == EvaluatedParameters.SearchText)
				x_finish(Environment, "yes")
			else
				x_finish(Environment, "no")
		}
	}
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_String_Contains_Text(Environment, ElementParameters)
{
}






