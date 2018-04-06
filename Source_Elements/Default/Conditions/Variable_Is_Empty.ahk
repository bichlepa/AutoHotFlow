;Always add this element class name to the global list
x_RegisterElementClass("Condition_Variable_Is_Empty")

;Element type of the element
Element_getElementType_Condition_Variable_Is_Empty()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_Variable_Is_Empty()
{
	return lang("Variable_Is_Empty")
}

;Category of the element
Element_getCategory_Condition_Variable_Is_Empty()
{
	return lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Variable_Is_Empty()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Variable_Is_Empty()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_Variable_Is_Empty()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Variable_Is_Empty()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Variable_Is_Empty(Environment)
{
	parametersToEdit:=Object()
	
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Variable_Is_Empty(Environment, ElementParameters)
{
	return lang("Variable_Is_Empty") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Variable_Is_Empty(Environment, ElementParameters)
{	
	
	parametersToEdit.push({type: "Label", label:  lang("Variable name")})
	parametersToEdit.push({type: "Edit", id: "VarName", default: "Varname", content: "VariableName", WarnIfEmpty: true})
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Variable_Is_Empty(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	temp:=x_GetVariable(Environment,EvaluatedParameters.Varname)
	
	if (temp = "")
		x_finish(Environment,"yes")
	else
		x_finish(Environment,"no")
		
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Variable_Is_Empty(Environment, ElementParameters)
{
}






