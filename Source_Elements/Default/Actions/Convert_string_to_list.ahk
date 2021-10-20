;Always add this element class name to the global list
x_RegisterElementClass("Action_Convert_string_to_list")

;Element type of the element
Element_getElementType_Action_Convert_string_to_list()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Convert_string_to_list()
{
	return x_lang("Convert string to list")
}

;Category of the element
Element_getCategory_Action_Convert_string_to_list()
{
	return x_lang("List")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Convert_string_to_list()
{
	return "Default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Convert_string_to_list()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Convert_string_to_list()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Convert_string_to_list()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Convert_string_to_list(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output list name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "MyList", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "myString", content: ["String", "Expression"], contentID: "expression", contentDefault: "Expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Input format")})
	parametersToEdit.push({type: "Radio", id: "listToStringOutputFormat", result: "enum", default: "JSON", choices: ["JSON", "YAML"], enum: ["JSON", "YAML"]})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Convert_string_to_list(Environment, ElementParameters)
{
	return x_lang("Convert %1%-string to list '%2%'", ElementParameters.listToStringOutputFormat, ElementParameters.VarValue) " - " ElementParameters.Varname
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Convert_string_to_list(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Convert_string_to_list(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get string
	myString := EvaluatedParameters.VarValue
	
	; check whether we got a string
	if (IsObject(myString))
	{
		x_finish(Environment, "exception", x_lang("Expression '%1%' does not contain a string.", ElementParameters.VarValue)) 
		return
	}

	; convert
	switch (EvaluatedParameters.listToStringOutputFormat)
	{
		case "JSON":
		try
		{
			outputList := Default_Lib_Jxon_Load(myString)
		}
		catch e
		{
			x_finish(Environment, "exception", x_lang("Error converting string to list") " - " e.Message)
			return
		}
		case "YAML":
		outputList := Default_Lib_Yaml(myString, 0)
	}

	; write output string to variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, outputList)


	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Convert_string_to_list(Environment, ElementParameters)
{
}



