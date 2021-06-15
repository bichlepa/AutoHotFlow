;Always add this element class name to the global list
x_RegisterElementClass("Action_Trigonometry")

;Element type of the element
Element_getElementType_Action_Trigonometry()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Trigonometry()
{
	return x_lang("Trigonometry")
}

;Category of the element
Element_getCategory_Action_Trigonometry()
{
	return x_lang("Maths")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Trigonometry()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Trigonometry()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Trigonometry()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Trigonometry()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Trigonometry(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Input number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 0.5, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Operation")})
	parametersToEdit.push({type: "Radio", id: "Operation", default: "Sine", choices: [x_lang("Sine"), x_lang("Cosine"), x_lang("Tangent"), x_lang("Arcsine"), x_lang("Arccosine"), x_lang("Arctangent")], result: "enum", enum: ["Sine", "Cosine", "Tangent", "Arcsine", "Arccosine", "Arctangent"]})
	parametersToEdit.push({type: "Label", label:  x_lang("Unit")})
	parametersToEdit.push({type: "Radio", id: "Unit", default: "Radian", choices: [x_lang("Radian"), x_lang("Degree")], result: "enum", enum: ["Radian", "Degree"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Trigonometry(Environment, ElementParameters)
{
	; calculate result based on operation
	switch (ElementParameters.Operation)
	{
		case "Sine":
		operationText := x_lang("Sine")
		case "Cosine":
		operationText := x_lang("Cosine")
		case "Tangent":
		operationText := x_lang("Tangent")
		case "Arcsine":
		operationText := x_lang("Arcsine")
		case "Arccosine":
		operationText := x_lang("Arccosine")
		case "Arctangent":
		operationText := x_lang("Arctangent")
	}
	return x_lang("Trigonometry") " - " operationText " - " ElementParameters.Varname " - " ElementParameters.VarValue
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Trigonometry(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Trigonometry(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; copy value to shorter variable
	Operation := EvaluatedParameters.Operation
	
	; If input is an angle
	if (Operation = "Sine" or Operation = "Cosine" or Operation = "Tangent")
	{
		if (EvaluatedParameters.Unit = "Degree") 
		{
			; convert degree to radian
			EvaluatedParameters.VarValue /= 180 / 3.141592653589793
		}
	}

	; calculate result based on operation
	switch (Operation)
	{
		case "Sine":
		Result := Sin(EvaluatedParameters.VarValue)
		case "Cosine":
		Result := Cos(EvaluatedParameters.VarValue)
		case "Tangent":
		Result := Tan(EvaluatedParameters.VarValue)
		case "Arcsine":
		Result := ASin(EvaluatedParameters.VarValue)
		case "Arccosine":
		Result := ACos(EvaluatedParameters.VarValue)
		case "Arctangent":
		Result := ATan(EvaluatedParameters.VarValue)
	}

	; If output is an angle
	if (Operation = "Arcsine" or Operation = "Arccosine" or Operation = "Arctangent")
	{
		if (EvaluatedParameters.Unit = "Degree")
		{
			; convert radian to degree
			Result *= 180 / 3.141592653589793
		}
	}
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Result)

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Trigonometry(Environment, ElementParameters)
{
}






