
;Name of the element
Element_getName_Action_Convert_list_to_string()
{
	return x_lang("Convert list to string")
}

;Category of the element
Element_getCategory_Action_Convert_list_to_string()
{
	return x_lang("List")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Convert_list_to_string()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Convert_list_to_string()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Convert_list_to_string()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Convert_list_to_string(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "MyString", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Output format")})
	parametersToEdit.push({type: "Radio", id: "listToStringOutputFormat", result: "enum", default: "JSON", choices: ["JSON", "YAML"], enum: ["JSON", "YAML"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "compactMode", default: 0, label: x_lang("Compact mode")})
	parametersToEdit.push({type: "Label", label: x_lang("Indentation length"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "indentationLength", default: 2, content: "PositiveInteger", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Convert_list_to_string(Environment, ElementParameters)
{
	return x_lang("Convert list '%1%' to %2%-string", ElementParameters.ListName, ElementParameters.listToStringOutputFormat) " - " ElementParameters.Varname
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Convert_list_to_string(Environment, ElementParameters, staticValues)
{	
	x_Par_Enable("compactMode", ElementParameters.listToStringOutputFormat = "JSON")
	x_Par_Enable("indentationLength", ElementParameters.listToStringOutputFormat = "JSON" and not ElementParameters.compactMode)
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Convert_list_to_string(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["indentationLength"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}


	; get list
	myList := EvaluatedParameters.ListName
	
	; check whether we got a list
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", x_lang("Expression '%1%' does not contain a list.", ElementParameters.ListName)) 
		return
	}

	; convert
	switch (EvaluatedParameters.listToStringOutputFormat)
	{
		case "JSON":
		
		try
		{
			if (EvaluatedParameters.compactMode)
			{
				outputString := Default_Lib_Jxon_Dump(myList)
			}
			else
			{
				; evaluate more parameters
				x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["indentationLength"])
				if (EvaluatedParameters._error)
				{
					return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				}
				outputString := Default_Lib_Jxon_Dump(myList, EvaluatedParameters.indentationLength)
			}
		}
		catch e
		{
			x_finish(Environment, "exception", x_lang("Error converting list to string") " - " e.Message)
			return
		}
		case "YAML":
		outputString := Default_Lib_Yaml_Dump(myList)
	}

	; write output string to variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, outputString)

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Convert_list_to_string(Environment, ElementParameters)
{
}



