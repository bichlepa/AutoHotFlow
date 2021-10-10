;Always add this element class name to the global list
x_RegisterElementClass("Action_New_variable")

;Element type of the element
Element_getElementType_Action_New_variable()
{
	return "action"
}

;Name of the element
Element_getName_Action_New_variable()
{
	return x_lang("New_variable")
}

;Category of the element
Element_getCategory_Action_New_variable()
{
	return x_lang("Variable") "|" x_lang("Text") "|" x_lang("Maths")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_New_variable()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_New_variable()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_New_variable()
{
	return "New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_New_variable()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_New_variable(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Value")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"], contentID: "expression", contentDefault: "string"})

	parametersToEdit.push({type: "Label", label:  x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "onlyIfNotExist", default: 0, label: x_lang("Write only if variable does not exist")})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_New_variable(Environment, ElementParameters)
{
	global
	return % x_lang("New_variable") " - " ElementParameters.Varname " = " ElementParameters.VarValue
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_New_variable(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_New_variable(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; set output variable
	if (EvaluatedParameters.onlyIfNotExist)
	{
		varLoc := x_GetVariableLocation(Environment, EvaluatedParameters.Varname)
		if varLoc
		{
			x_finish(Environment, "normal", "Variable was not written, because it already exists.")
			return
		}
	}
	x_SetVariable(Environment, EvaluatedParameters.Varname, EvaluatedParameters.VarValue)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_New_variable(Environment, ElementParameters)
{
	
}

