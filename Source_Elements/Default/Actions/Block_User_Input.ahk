﻿
;Name of the element
Element_getName_Action_Block_User_Input()
{
	return x_lang("Block user input")
}

;Category of the element
Element_getCategory_Action_Block_User_Input()
{
	return x_lang("User interaction")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Block_User_Input()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Block_User_Input()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Block_User_Input()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Block_User_Input(Environment)
{
	;~ d( x_GetListOfAllVars(environment))
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("New block state")})
	parametersToEdit.push({type: "Radio", id: "blockState", result: "enum", default: "Block", choices: [x_lang("Block user input"), x_lang("Unblock user input")], enum: ["Block", "Unblock"]})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Block_User_Input(Environment, ElementParameters)
{
	if (ElementParameters.blockState = "Block")
	{
		return % x_lang("Block user input")
	}
	Else
	{
		return % x_lang("Unblock user input")
	}
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Block_User_Input(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Block_User_Input(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (EvaluatedParameters.blockState = "block")
		BlockInput, ON
	Else
		BlockInput, OFF
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Block_User_Input(Environment, ElementParameters)
{
	
}
