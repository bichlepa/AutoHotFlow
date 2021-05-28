;Always add this element class name to the global list
x_RegisterElementClass("Action_AutoHotKey_script")

;Element type of the element
Element_getElementType_Action_AutoHotKey_script()
{
	return "Action"
}

;Name of the element
Element_getName_Action_AutoHotKey_script()
{
	return x_lang("AutoHotKey_script")
}

;Category of the element
Element_getCategory_Action_AutoHotKey_script()
{
	return x_lang("Expert")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_AutoHotKey_script()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_AutoHotKey_script()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Programmer"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_AutoHotKey_script()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_AutoHotKey_script()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_AutoHotKey_script(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("AutoHotKey_script"), WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "Script", default: "", WarnIfEmpty: false})

	parametersToEdit.push({type: "Label", label: x_lang("Variables_that_should_be_imported_to_script_prior_to_execution")})
	parametersToEdit.push({type: "edit", id: "ImportVariables", content: "String", multiline: true})

	parametersToEdit.push({type: "Label", label: x_lang("Variables_that_should_be_exported_from_script_after_execution")})
	parametersToEdit.push({type: "edit", id: "ExportVariables", content: "String", multiline: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_AutoHotKey_script(Environment, ElementParameters)
{
	return x_lang("AutoHotKey_script") "`n" substr(ElementParameters.script, 1, 50)
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_AutoHotKey_script(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_AutoHotKey_script(Environment, ElementParameters)
{
	; evaluate parameters
	x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["ImportVariables", "ExportVariables"])
	if (ElementParameters._error)
	{
		return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
	}

	; script does not need to be evaluated
	script := ElementParameters.script

	; Make list of all input variables
	inputVars := Object()
	loop, parse, % EvaluatedParameters.ImportVariables, |`,`n%a_space%
	{
		if not A_LoopField
			continue
		inputVars[A_LoopField] := x_GetVariable(Environment, A_LoopField)
	}
	
	; Make list of all output variables
	outputVars := Object()
	loop, parse, % EvaluatedParameters.ExportVariables, |`,`n%a_space%
	{
		if not A_LoopField
			continue
		outputVars.push(A_LoopField)
	}
	; also add variables result and resultmessage as output variables
	outputVars.push("result", "resultmessage")

	; create function object and start AHK script in new thread
	functionObject := x_NewFunctionObject(Environment, "Action_AutoHotKey_script_FinishExecution", ElementParameters)
	x_ExecuteInNewAHKThread(Environment, functionObject, script, inputVars, outputVars)
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_AutoHotKey_script(Environment, ElementParameters)
{
	; stop the other AHK thread
	x_ExecuteInNewAHKThread_Stop(Environment)
}

; function will be called when the external AHK thread finishes
Action_AutoHotKey_script_FinishExecution(Environment, ElementParameters, values)
{
	; values contains the output values from the script. Set them as instance variables
	for onevaluekey, onevalue in values
	{
		x_SetVariable(Environment, onevaluekey, onevalue)
	}

	; check value "exception"
	if (values.result != "exception")
	{
		; external script did not report any exception. Finisch normally
		x_finish(Environment, "normal", values.message)
	}
	else
	{
		; There was an exception
		if (values.message)
		{
			; script returned an exception message. Finish with exception and add the exception
			x_finish(Environment, "exception", values.message)
		}
		else
		{
			; script did not return an exception message. Finish with a static message.
			x_finish(Environment, "exception", "Unknown error")
		}
	}
}



