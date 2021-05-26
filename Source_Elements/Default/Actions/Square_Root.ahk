;Always add this element class name to the global list
x_RegisterElementClass("Action_Square_Root")

;Element type of the element
Element_getElementType_Action_Square_Root()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Square_Root()
{
	return x_lang("Square_Root")
}

;Category of the element
Element_getCategory_Action_Square_Root()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Square_Root()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Square_Root()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Square_Root()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Square_Root()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Square_Root(Environment)
{
	parametersToEdit:=Object()
	
	
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Variable containing a number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 16, content: "Number", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Square_Root(Environment, ElementParameters)
{
	return x_lang("Square_Root") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Square_Root(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Square_Root(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}


	x_SetVariable(Environment,EvaluatedParameters.Varname,sqrt(EvaluatedParameters.VarValue))
	x_finish(Environment,"normal")
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Square_Root(Environment, ElementParameters)
{
}






