
;Name of the element
Element_getName_Action_Split_path()
{
	return x_lang("Split path")
}

;Category of the element
Element_getCategory_Action_Split_path()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Split_path()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Split_path()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Split_path()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Split_path(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file"), warnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variables")})
	parametersToEdit.push({type: "Label", label: x_lang("File name"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutFileName", default: "fileName", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Directory"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutDir", default: "directory", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("File extension"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutExtension", default: "fileExtension", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("File name without extension"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutNameNoExt", default: "fileNameNoExtension", content: "VariableName"})
	parametersToEdit.push({type: "Label", label: x_lang("Drive"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "OutDrive", default: "drive", content: "VariableName"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Split_path(Environment, ElementParameters)
{
	return x_lang("Split path") " - " ElementParameters.file
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Split_path(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Split_path(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; split the path
	splitpath, % EvaluatedParameters.File, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive

	; set output variables
	x_SetVariable(Environment, EvaluatedParameters.OutFileName, OutFileName)
	x_SetVariable(Environment, EvaluatedParameters.OutDir, OutDir)
	x_SetVariable(Environment, EvaluatedParameters.OutExtension, OutExtension)
	x_SetVariable(Environment, EvaluatedParameters.OutNameNoExt, OutNameNoExt)
	x_SetVariable(Environment, EvaluatedParameters.OutDrive, OutDrive)
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Split_path(Environment, ElementParameters)
{
}



