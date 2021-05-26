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
	return x_lang("Variable")
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
	parametersToEdit.push({type: "Radio", id: "Operation", default: 2, choices: [x_lang("Sine"), x_lang("Cosine"), x_lang("Tangent"), x_lang("Arcsine"), x_lang("Arccosine"), x_lang("Arctangent")], result: "enum", enum: ["Sine", "Cosine", "Tangent", "Arcsine", "Arccosine", "Arctangent"]})
	parametersToEdit.push({type: "Label", label:  x_lang("Unit")})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 1, choices: [x_lang("Radian"), x_lang("Degree")], result: "enum", enum: ["Radian", "Degree"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Trigonometry(Environment, ElementParameters)
{
	return x_lang("Trigonometry") 
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
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	Operation:=EvaluatedParameters.Operation
	Unit:=EvaluatedParameters.Unit
	VarValue:=EvaluatedParameters.VarValue
	
	if (Operation="Sine" or Operation="Cosine" or Operation="Tangent") ;If input is radian or degree
	{
		if (Unit="Degree") ;If degree, convert to radian
		{
			VarValue/=180/3.141592653589793
		}
	}
	if (Operation="Sine") ;Sine
		Result:=Sin(VarValue)
	else if (Operation="Cosine") ;Cosine
		Result:=Cos(VarValue)
	else if (Operation="Tangent") ;Tangent
		Result:=Tan(VarValue)
	else if (Operation="Arcsine") ;ASine
		Result:=ASin(VarValue)
	else if (Operation="Arccosine") ;ACosine
		Result:=ACos(VarValue)
	else if (Operation="Arctangent") ;ATangent
		Result:=ATan(VarValue)
	if (Operation="Arcsine" or Operation="Arccosine" or Operation="Arctangent") ;If output is radian or degree
	{
		if (Unit="Degree") ;If degree, convert from radian
		{
			Result*=180/3.141592653589793
		}
	}
	
	x_SetVariable(Environment,EvaluatedParameters.Varname,Result)
	x_finish(Environment,"normal")
	return
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Trigonometry(Environment, ElementParameters)
{
}






