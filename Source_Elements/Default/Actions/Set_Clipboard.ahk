;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_Clipboard")

;Element type of the element
Element_getElementType_Action_Set_Clipboard()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_Clipboard()
{
	return x_lang("Set_Clipboard")
}

;Category of the element
Element_getCategory_Action_Set_Clipboard()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_Clipboard()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Clipboard()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Set_Clipboard()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Clipboard()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Clipboard(Environment)
{
	parametersToEdit:=Object()
	
	
	parametersToEdit.push({type: "Edit", id: "text", default: "New element", content: ["string", "expression"], contentID: "expression", contentDefault: "string"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Clipboard(Environment, ElementParameters)
{
	return x_lang("Set_Clipboard") " - " ElementParameters.text
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Clipboard(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Clipboard(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; set clipboard content
	Clipboard := EvaluatedParameters.text
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Clipboard(Environment, ElementParameters)
{
}






