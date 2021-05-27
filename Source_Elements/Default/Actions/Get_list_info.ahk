;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_List_Info")

;Element type of the element
Element_getElementType_Action_Get_List_Info()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_List_Info()
{
	return x_lang("Get_List_Info")
}

;Category of the element
Element_getCategory_Action_Get_List_Info()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_List_Info()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_List_Info()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_List_Info()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_List_Info()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_List_Info(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "ListInfo", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label:  x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "List", default: "myList", content: "Expression", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("WhichInfo")})
	parametersToEdit.push({type: "Radio", id: "WhichInfo", default: "maxIndex", result: "enum", choices: [x_lang("Minimum index"), x_lang("Maximum index"), x_lang("Array length"), x_lang("Element count")], enum: ["minIndex", "maxIndex", "length", "count"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_List_Info(Environment, ElementParameters)
{
	switch ElementParameters.WhichInfo
	{
	case "minIndex":
		value := x_lang("Minimum index of %1%", ElementParameters.List)
	case "maxIndex":
		value := x_lang("Maximum index of %1%", ElementParameters.List)
	case "length":
		value := x_lang("Array length of %1%", ElementParameters.List)
	case "count":
		value := x_lang("Element count of %1%", ElementParameters.List)
	}

	return x_lang("Get list info") "`n" ElementParameters.Varname " = " value
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_List_Info(Environment, ElementParameters, staticValues)
{
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_List_Info(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; error if variable does not contain a list
	if (not IsObject(EvaluatedParameters.List))
	{
		x_finish(Environment, "exception", lang("'%1%' does not contain a list", EvaluatedParameters.List))
		return
	}
	
	; get the desired info
	switch EvaluatedParameters.WhichInfo
	{
	case "minIndex":
		value := EvaluatedParameters.List.MinIndex()
	case "maxIndex":
		value := EvaluatedParameters.List.MaxIndex()
	case "length":
		value := EvaluatedParameters.List.Length()
	case "count":
		value := EvaluatedParameters.List.Count()
	}

	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, value)
	
	; finish
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the taks takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_List_Info(Environment, ElementParameters)
{
	
}


