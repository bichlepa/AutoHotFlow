;Always add this element class name to the global list
AllElementClasses.push("Condition_Key_Is_Down")

;Element type of the element
Element_getElementType_Condition_Key_Is_Down()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_Key_Is_Down()
{
	return lang("Key_Is_Down")
}

;Category of the element
Element_getCategory_Condition_Key_Is_Down()
{
	return lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Key_Is_Down()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Key_Is_Down()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_Key_Is_Down()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Key_Is_Down()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Key_Is_Down(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Key name")})
	parametersToEdit.push({type: "Edit", id: "key", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Key_Is_Down(Environment, ElementParameters)
{
	return lang("Key_Is_Down") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Key_Is_Down(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Key_Is_Down(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	
	GetKeyState,tempKeyState,% EvaluatedParameters.key
	
	
	if (tempKeyState="d")
		x_finish(Environment,"yes")
	else if (tempKeyState="u")
		x_finish(Environment,"no")
	else
	{
		x_finish(Environment, "exception", lang("Couldn't get state of key '%1%'", EvaluatedParameters.key)) 
		return
	}
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Key_Is_Down(Environment, ElementParameters)
{
}






