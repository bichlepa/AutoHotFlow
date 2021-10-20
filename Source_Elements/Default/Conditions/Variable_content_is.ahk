;Always add this element class name to the global list
x_RegisterElementClass("Condition_Variable_content_is")

;Element type of the element
Element_getElementType_Condition_Variable_content_is()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_Variable_content_is()
{
	return x_lang("Variable content is")
}

;Category of the element
Element_getCategory_Condition_Variable_content_is()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Variable_content_is()
{
	return "Default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Variable_content_is()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Condition_Variable_content_is()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Variable_content_is()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Variable_content_is(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Variable name or expression")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "myVariable", content: ["VariableName", "Expression"], contentID: "varnameContent", contentDefault: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Expected content type")})
	parametersToEdit.push({type: "Radio", id: "variableContentType", result: "enum", default: "object", choices: [x_lang("List"), x_lang("Time"), x_lang("Number"), x_lang("Integer"), x_lang("Floating point number"), x_lang("Decimal digits"), x_lang("Hexadecimal digits"), x_lang("Alphanumeric string"), x_lang("Alphabetic string"), x_lang("String with only uppercase characters"), x_lang("String with only lowercase characters"), x_lang("Whitespaces")], enum: ["object", "time", "number", "integer", "float", "digit", "xdigit", "alnum", "alpha", "upper", "lower", "space"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Variable_content_is(Environment, ElementParameters)
{
	switch (ElementParameters.variableContentType)
	{
		case "object":
		typeText := x_lang("List")
		case "time":
		typeText := x_lang("Time")
		case "number":
		typeText := x_lang("Number")
		case "integer":
		typeText := x_lang("Integer")
		case "float":
		typeText := x_lang("Floating point number")
		case "digit":
		typeText := x_lang("Decimal digits")
		case "xdigit":
		typeText := x_lang("Hexadecimal digits")
		case "alnum":
		typeText := x_lang("Alphanumeric string")
		case "alpha":
		typeText := x_lang("Alphabetic string")
		case "upper":
		typeText := x_lang("String with only uppercase characters")
		case "lower":
		typeText := x_lang("String with only lowercase characters")
		case "space":
		typeText := x_lang("Whitespaces")
	}

	return x_lang("Variable content is %1%", typeText) " - " ElementParameters.varname
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Variable_content_is(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Variable_content_is(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; write the value in a variable
	if (ElementParameters.varnameContent = "VariableName")
	{
		value := x_getVariable(Environment, EvaluatedParameters.varname)
	}
	Else
	{
		value := EvaluatedParameters.varname
	}

	; check the content type
	result := false
	switch (ElementParameters.variableContentType)
	{
		case "object":
		; check whether value is an object
		if (isobject(value))
		{
			result := true
		}
		default:
		; all enum values are same as the AHK command "If var is [not] type"
		type := ElementParameters.variableContentType
		if value is %type%
		{
			result := true
		}
	}
	
	if result
		x_finish(Environment, "yes")
	else
		x_finish(Environment, "no")
		
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Variable_content_is(Environment, ElementParameters)
{
}




