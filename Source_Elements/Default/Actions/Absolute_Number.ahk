;Always add this element class name to the global list
x_RegisterElementClass("Action_Absolute_number")

;Element type of the element
Element_getElementType_Action_Absolute_number()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Absolute_number()
{
	return x_lang("Absolute_number")
}

;Category of the element
Element_getCategory_Action_Absolute_number()
{
	return x_lang("Maths")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Absolute_number()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Absolute_number()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Absolute_number()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Absolute_number()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Absolute_number(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output_Variable_name")})
	parametersToEdit.push({type: "edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Input number")})
	parametersToEdit.push({type: "edit", id: "VarValue", default: -2, content: "Expression", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Absolute_number(Environment, ElementParameters)
{
	return x_lang("Absolute_number") "`n" ElementParameters.Varname " = |" ElementParameters.VarValue "|"
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Absolute_number(Environment, ElementParameters, staticValues)
{
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Absolute_number(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check whether value is a number
	VarValue := EvaluatedParameters.VarValue
	if VarValue is not number
	{
		x_finish(Environment, "exception", x_lang("Value is not a number: %1%", VarValue))
		return 
	}

	; get absolute number
	VarValue := abs(VarValue)

	; write value to the variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, VarValue)
	
	; finish
	x_finish(Environment, "normal")
}

;Called when the execution of the element should be stopped.
;If the taks takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Absolute_number(Environment, ElementParameters)
{
	
}


