﻿
;Name of the element
Element_getName_Action_Get_Clipboard()
{
	return x_lang("Get_Clipboard")
}

;Category of the element
Element_getCategory_Action_Get_Clipboard()
{
	return x_lang("Variable")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Clipboard()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Get_Clipboard()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Clipboard()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Clipboard(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output_Variable_name")})
	parametersToEdit.push({type: "edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Clipboard(Environment, ElementParameters)
{
	return x_lang("Get_Clipboard") "`n" ElementParameters.Varname
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Clipboard(Environment, ElementParameters, staticValues)
{
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Clipboard(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; get clipboard and set it to output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, Clipboard)
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the taks takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Clipboard(Environment, ElementParameters)
{
	
}


