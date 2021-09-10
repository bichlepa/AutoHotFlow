;Always add this element class name to the global list
x_RegisterElementClass("Action_Trim_a_string")

;Element type of the element
Element_getElementType_Action_Trim_a_string()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Trim_a_string()
{
	return x_lang("Trim_a_string")
}

;Category of the element
Element_getCategory_Action_Trim_a_string()
{
	return x_lang("Text")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Trim_a_string()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Trim_a_string()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Trim_a_string()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Trim_a_string()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Trim_a_string(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Operation")})
	parametersToEdit.push({type: "Radio", id: "TrimWhat", default: "Number", choices: [x_lang("Remove a number of characters"), x_lang("Remove Specified caracters")], result: "enum", enum: ["Number", "Specified"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Remove from which side")})
	parametersToEdit.push({type: "CheckBox", id: "LeftSide", default: 1, label: x_lang("Left-hand side")})
	parametersToEdit.push({type: "CheckBox", id: "RightSide", default: 0, label: x_lang("Right-hand side")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Count of characters")})
	parametersToEdit.push({type: "Edit", id: "Length", default: 6, content: "Number", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Which characters")})
	parametersToEdit.push({type: "Edit", id: "OmitChars", default: "%a_space%%a_tab%%a_lf%%a_cr%", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Trim_a_string(Environment, ElementParameters)
{
	if (ElementParameters.LeftSide and ElementParameters.RightSide)
	{
		sideText := x_lang("both sides")
	}
	else if (ElementParameters.LeftSide)
	{
		sideText := x_lang("left side")
	}
	else if (ElementParameters.RightSide)
	{
		sideText := x_lang("right side")
	}
	switch (ElementParameters.TrimWhat)
	{
		case "number":
		trimWhatText := x_lang("Remove '%1%' characters from %2%", ElementParameters.Length, sideText)

		case "specified":
		trimWhatText := x_lang("Remove characters '%1%' from %2%", ElementParameters.OmitChars, sideText)
	}
	return x_lang("Trim_a_string") " - " ElementParameters.Varname " - " ElementParameters.VarValue " - " trimWhatText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Trim_a_string(Environment, ElementParameters, staticValues)
{	
	static previousLeftSide = 0
	static previousRightSide = 0
	
	if (ElementParameters.TrimWhat = "Number") ;Trim a count of characters
	{
		x_Par_Enable("Length")
		x_Par_Disable("WhiteSpaces")
		x_Par_Disable("OmitChars")
	}
	else ;Trim Specified characters
	{
		x_Par_Disable("Length")
		x_Par_Enable("WhiteSpaces")
		x_Par_Enable("OmitChars")
	}
	
	if (ElementParameters.LeftSide = 0 and ElementParameters.RightSide = 0)
	{
		if (previousRightSide = 1)
		{
			x_Par_SetValue("LeftSide", 1)
			previousLeftSide = 1
			previousRightSide = 0
		}
		else
		{
			x_Par_SetValue("RightSide", 1)
			previousRightSide = 1
			previousLeftSide = 0
		}
	}
	else
	{
		previousLeftSide := ElementParameters.LeftSide
		previousRightSide := ElementParameters.RightSide
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Trim_a_string(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["Length", "OmitChars"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; decide what to do
	if (EvaluatedParameters.TrimWhat = "Number")
	{
		; Trim a number of characters
		
		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Length"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		; trim the defined number of characters
		result := EvaluatedParameters.VarValue
		if (EvaluatedParameters.LeftSide)
			StringTrimLeft, result, result, % EvaluatedParameters.Length
		if (EvaluatedParameters.RightSide)
			StringTrimRight, result, result, % EvaluatedParameters.Length
	}
	else if (EvaluatedParameters.TrimWhat = "Specified")
	{
		; Trim Specified characters

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["OmitChars"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		; trim the defined characters
		if (EvaluatedParameters.LeftSide and EvaluatedParameters.RightSide)
			Result := Trim(EvaluatedParameters.VarValue,EvaluatedParameters.OmitChars)
		else if (EvaluatedParameters.LeftSide)
			Result := LTrim(EvaluatedParameters.VarValue,EvaluatedParameters.OmitChars)
		else if (EvaluatedParameters.RightSide)
			Result := RTrim(EvaluatedParameters.VarValue,EvaluatedParameters.OmitChars)
	}
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Result)

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Trim_a_string(Environment, ElementParameters)
{
}






