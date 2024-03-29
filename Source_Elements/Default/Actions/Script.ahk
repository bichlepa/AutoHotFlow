﻿
;Name of the element
Element_getName_Action_Script()
{
	return x_lang("Script")
}

;Category of the element
Element_getCategory_Action_Script()
{
	return x_lang("Variable")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Script()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Script()
{
	return "New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Script()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Script(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "label", label: x_lang("Script")})
	parametersToEdit.push({type: "multilineEdit", id: "Script", content: "RawString", default: "", WarnIfEmpty: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Script(Environment, ElementParameters)
{
	global
	return % x_lang("Script") " - " ElementParameters.Script 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Script(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Script(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, "WorkingDir")
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; run script
	result := x_EvaluateScript(Environment, EvaluatedParameters.Script)
	if (result.errors)
	{
		x_finish(Environment, "exception", result.errors) 
		return
	}
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Script(Environment, ElementParameters)
{
	
}

