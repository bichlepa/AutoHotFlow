;Always add this element class name to the global list
x_RegisterElementClass("Action_Rounding_A_Number")

;Element type of the element
Element_getElementType_Action_Rounding_A_Number()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Rounding_A_Number()
{
	return x_lang("Rounding_A_Number")
}

;Category of the element
Element_getCategory_Action_Rounding_A_Number()
{
	return x_lang("Maths")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Rounding_A_Number()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Rounding_A_Number()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Rounding_A_Number()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Rounding_A_Number()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Rounding_A_Number(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Input number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 1.2345, content: "Number", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label:  x_lang("Places after comma")})
	parametersToEdit.push({type: "Edit", id: "Places", default: 0, content: "Number", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Operation")})
	parametersToEdit.push({type: "Radio", id: "Roundingtype", default: "round", choices: [x_lang("Round normally"), x_lang("Round up"), x_lang("Round down")], result: "enum", enum: ["round", "roundUp", "roundDown"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Rounding_A_Number(Environment, ElementParameters)
{
	return x_lang("Rounding_A_Number") " - " ElementParameters.Varname " - " ElementParameters.VarValue " - " ElementParameters.Places
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Rounding_A_Number(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Rounding_A_Number(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	switch (EvaluatedParameters.roundingtype)
	{
		case "round":
		; round normally
		Result := round(EvaluatedParameters.VarValue, EvaluatedParameters.Places)
		case "roundUp":
		; round up

		; first round normally
		Result := round(EvaluatedParameters.VarValue, EvaluatedParameters.Places)

		; check whether result is smaller than the original value
		if (Result < EvaluatedParameters.VarValue)
		{
			; add a digit
			Result += 10 ** (-EvaluatedParameters.Places)

			; round again (to split off trailing zeros)
			Result := round(Result, EvaluatedParameters.Places)
		}

		case "roundDown":
		; round up
		
		; first round normally
		Result := round(EvaluatedParameters.VarValue, EvaluatedParameters.Places)

		; check whether result is greater than the original value
		if (Result > EvaluatedParameters.VarValue)
		{
			; substract a digit
			Result -= 10**(-EvaluatedParameters.Places)

			; round again (to split off trailing zeros)
			Result := round(Result, EvaluatedParameters.Places)
		}
	}

	; write output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Result)

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Rounding_A_Number(Environment, ElementParameters)
{
}






