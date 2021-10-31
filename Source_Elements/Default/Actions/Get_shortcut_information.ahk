
;Name of the element
Element_getName_Action_Get_shortcut_information()
{
	return x_lang("Get shortcut information")
}

;Category of the element
Element_getCategory_Action_Get_shortcut_information()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_shortcut_information()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Get_shortcut_information()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_shortcut_information()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_shortcut_information(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Shortcut path")})
	parametersToEdit.push({type: "File", id: "shortcutFile", label: x_lang("Select a shortcut file"), filter: x_lang("Shortcut file") " (*.lnk)", options: 32})

	parametersToEdit.push({type: "Label", label: x_lang("Output variables")})
	parametersToEdit.push({type: "Label", label: x_lang("Target path"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutTarget", default: "shortcutTarget", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Target arguments"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutArgs", default: "shortcutArgs", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Working directory"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutDir", default: "shortcutDir", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Description"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutDescription", default: "shortcutDescription", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Icon path"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutIcon", default: "shortcutIcon", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Icon number"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutIconNum", default: "shortcutIconNumber", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Run mode"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutRunState", default: "shortcutRunMode", content: "VariableName"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_shortcut_information(Environment, ElementParameters)
{
	return x_lang("Get shortcut information") " - " ElementParameters.shortcutFile
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_shortcut_information(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_shortcut_information(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; read shortcut informations
	FileGetShortcut, % EvaluatedParameters.shortcutFile, OutTarget, OutDir, OutArgs, OutDescription, OutIcon, OutIconNum, OutRunState

	; check for errors
	if (ErrorLevel)
	{
		x_finish(Environment, "exception", x_lang("Can't read informations of shortcut '%1%'", EvaluatedParameters.shortcutFile))
		return
	}

	; set output variables
	x_SetVariable(Environment, EvaluatedParameters.OutTarget, OutTarget)
	x_SetVariable(Environment, EvaluatedParameters.OutDir, OutDir)
	x_SetVariable(Environment, EvaluatedParameters.OutArgs, OutArgs)
	x_SetVariable(Environment, EvaluatedParameters.OutDescription, OutDescription)
	x_SetVariable(Environment, EvaluatedParameters.OutIcon, OutIcon)
	x_SetVariable(Environment, EvaluatedParameters.OutIconNum, OutIconNum)

	switch (OutRunState)
	{
		case 1:
		x_SetVariable(Environment, EvaluatedParameters.OutRunState, "Normal")
		case 3:
		x_SetVariable(Environment, EvaluatedParameters.OutRunState, "Maximized")
		case 7:
		x_SetVariable(Environment, EvaluatedParameters.OutRunState, "Minimized")
		default:
		x_SetVariable(Environment, EvaluatedParameters.OutRunState, x_lang("Unknown (%1%)", OutRunState))
	}



	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_shortcut_information(Environment, ElementParameters)
{
}



