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
	return lang("AutoHotKey_script")
}

;Category of the element
Element_getCategory_Action_AutoHotKey_script()
{
	return lang("Expert")
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
	parametersToEdit.push({type: "Label", label: lang("AutoHotKey_script"), WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "Script", default: "", WarnIfEmpty: false})
	parametersToEdit.push({type: "Label", label: lang("Variables_that_should_be_imported_to_script_prior_to_execution")})
	parametersToEdit.push({type: "edit", id: "ImportVariables", multiline: true})
	parametersToEdit.push({type: "Label", label: lang("Variables_that_should_be_exported_from_script_after_execution")})
	parametersToEdit.push({type: "edit", id: "ExportVariables", multiline: true})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_AutoHotKey_script(Environment, ElementParameters)
{
	return lang("AutoHotKey_script") "`n" substr(ElementParameters.script, 1, 50)
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_AutoHotKey_script(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_AutoHotKey_script(Environment, ElementParameters)
{
	ImportVariables := x_replaceVariables(Environment,ElementParameters.ImportVariables)
	ExportVariables := x_replaceVariables(Environment, ElementParameters.ExportVariables)
	script := ElementParameters.script

	;Write all local variables in the script
	inputVars:=Object()
	loop,parse,ImportVariables,|`,`n%a_space%
	{
		if not A_LoopField
			continue
		
		inputVars[A_LoopField] := x_GetVariable(Environment, A_LoopField)
	}
	
	;Get all local variables from the script
	outputVars:=Object()
	loop,parse,ExportVariables,|`,`n%a_space%
	{
		if not A_LoopField
			continue
		outputVars.push(A_LoopField)
	}
	outputVars.push("result", "resultmessage")
	
	
	functionObject := x_NewFunctionObject(Environment, "Action_AutoHotKey_script_FinishExecution", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	x_SetExecutionValue(Environment, "Varname", Varname)
	x_ExecuteInNewAHKThread(Environment, functionObject, script, inputVars, outputVars)
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_AutoHotKey_script(Environment, ElementParameters)
{
	x_ExecuteInNewAHKThread_Stop(Environment)
}


Action_AutoHotKey_script_FinishExecution(Environment, ElementParameters, values)
{
	for onevaluekey, onevalue in values
	{
		x_SetVariable(Environment, onevaluekey, onevalue)
	}
	if (values.result != "exception") ;we ignore any values other than "exception"
	{
		x_finish(Environment, "normal", values.message)
	}
	else
	{
		if (values.message)
		{
			x_finish(Environment, "exception", values.message)
		}
		else
		{
			x_finish(Environment, "exception", "Unknown error")
		}
	}
	
}



