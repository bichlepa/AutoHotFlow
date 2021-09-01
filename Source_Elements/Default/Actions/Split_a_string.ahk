;Always add this element class name to the global list
x_RegisterElementClass("Action_Split_a_string")

;Element type of the element
Element_getElementType_Action_Split_a_string()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Split_a_string()
{
	return x_lang("Split_a_string")
}

;Category of the element
Element_getCategory_Action_Split_a_string()
{
	return x_lang("Text")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Split_a_string()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Split_a_string()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Split_a_string()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Split_a_string()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Split_a_string(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output list name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello real world, Hello virtual world", content: ["String", "Expression"], contentID: "expression", contentDefault: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Delimiter characters")})
	parametersToEdit.push({type: "Edit", id: "Delimiters", default: ",", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Omit characters")})
	parametersToEdit.push({type: "Edit", id: "OmitChars", default: "%a_space%%a_tab%%a_lf%%a_cr%", content: "String"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Split_a_string(Environment, ElementParameters)
{
	return x_lang("Split_a_string") " - " ElementParameters.Varname " - " ElementParameters.VarValue " - " ElementParameters.Delimiters " - " ElementParameters.OmitChars
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Split_a_string(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Split_a_string(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; split the string
	Result := Object()
	loop, parse, % EvaluatedParameters.VarValue, % EvaluatedParameters.delimiters, % EvaluatedParameters.omitChars
	{
		Result.push(A_LoopField)
	}
	
	; set output variable
	x_SetVariable(Environment,EvaluatedParameters.varname,Result)
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Split_a_string(Environment, ElementParameters)
{
}






