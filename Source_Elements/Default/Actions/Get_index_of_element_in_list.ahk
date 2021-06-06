;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Index_Of_Element_In_List")

;Element type of the element
Element_getElementType_Action_Get_Index_Of_Element_In_List()
{
	return "action"
}

;Name of the element
Element_getName_Action_Get_Index_Of_Element_In_List()
{
	return x_lang("Get_Index_Of_Element_In_List")
}

;Category of the element
Element_getCategory_Action_Get_Index_Of_Element_In_List()
{
	return x_lang("List")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Index_Of_Element_In_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Index_Of_Element_In_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_Index_Of_Element_In_List()
{
	return "Source_elements\default\icons\New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Index_Of_Element_In_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Index_Of_Element_In_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Seeked content")})
	parametersToEdit.push({type: "Edit", id: "SearchContent", default: "keyName", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters)
{
	return % x_lang("Get position of element in list") " - " ElementParameters.Varname " - " ElementParameters.ListName " - " ElementParameters.SearchContent
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters, staticValues)
{
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get list from variable
	myList := EvaluatedParameters.ListName
	
	; check whether we got a list
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.", ElementParameters.ListName)) 
		return
	}
	
	;Search for the value in list
	found := false
	for oneKey, oneValue in myList
	{
		if (oneValue = EvaluatedParameters.SearchContent)
		{
			found := true
			result := oneKey
			break
		}
	}
	
	; check whether we found value
	if (found != true)
	{
		x_finish(Environment, "exception", x_lang("The list '%1%' does not contain the value '%2%'.", ElementParameters.ListName, Position))
		return
	}
	
	; set key name to variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Result)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters)
{
	
}

