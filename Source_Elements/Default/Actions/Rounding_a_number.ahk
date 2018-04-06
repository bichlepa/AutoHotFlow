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
	return lang("Rounding_A_Number")
}

;Category of the element
Element_getCategory_Action_Rounding_A_Number()
{
	return lang("Variable")
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

;Icon path which will be shown in the background of the element
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
	
	
	parametersToEdit.push({type: "Label", label: lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 1.2345, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Places after comma")})
	parametersToEdit.push({type: "Edit", id: "Places", default: 0, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Operation")})
	parametersToEdit.push({type: "Radio", id: "Roundingtype", default: 1, choices: [lang("Round normally"), lang("Round up"), lang("Round down")], result: "enum", enum: ["round", "roundUp", "roundDown"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Rounding_A_Number(Environment, ElementParameters)
{
	return lang("Rounding_A_Number") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Rounding_A_Number(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Rounding_A_Number(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (EvaluatedParameters.roundingtype="round") ;Normal rounding
	{
		tempResult:=round(EvaluatedParameters.VarValue,EvaluatedParameters.Places)
	}
	else if (EvaluatedParameters.roundingtype="roundUp") ;Rounding_a_number up
	{
		tempResult:=round(EvaluatedParameters.VarValue,EvaluatedParameters.Places)
		if (tempResult<EvaluatedParameters.VarValue)
		{
			tempResult+=10**(-EvaluatedParameters.Places)
			tempResult:=round(tempResult,EvaluatedParameters.Places)
		}
	}
	else if (EvaluatedParameters.roundingtype="roundDown") ;Rounding_a_number down
	{
		tempResult:=round(EvaluatedParameters.VarValue,EvaluatedParameters.Places)
		if (tempResult>EvaluatedParameters.VarValue)
		{
			tempResult-=10**(-EvaluatedParameters.Places)
			tempResult:=round(tempResult,EvaluatedParameters.Places)
		}	
	}
	x_SetVariable(Environment,EvaluatedParameters.Varname,tempResult) ;Example
	x_finish(Environment,"normal")
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Rounding_A_Number(Environment, ElementParameters)
{
}






