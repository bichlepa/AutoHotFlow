;Always add this element class name to the global list
x_RegisterElementClass("Action_Move_File")

;Element type of the element
Element_getElementType_Action_Move_File()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Move_File()
{
	return x_lang("Move_File")
}

;Category of the element
Element_getCategory_Action_Move_File()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Move_File()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Move_File()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Move_File()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Move_File()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Move_File(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Source file")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file")})
	parametersToEdit.push({type: "Label", label: x_lang("Destination file or folder")})
	parametersToEdit.push({type: "Folder", id: "destFile", label: x_lang("Select a file or folder")})
	parametersToEdit.push({type: "Label", label: x_lang("Overwrite")})
	parametersToEdit.push({type: "Checkbox", id: "Overwrite", default: 0, label: x_lang("Overwrite existing files")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Move_File(Environment, ElementParameters)
{
	return x_lang("Move_File") " - " ElementParameters.File " - " ElementParameters.destFile
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Move_File(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Move_File(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check whether files exist
	fileAttr := FileExist(EvaluatedParameters.file)
	if (not fileAttr)
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Source file"), EvaluatedParameters.file)) 
		return
	}
	if (instr(fileAttr, "D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is a folder.", x_lang("Source file"), EvaluatedParameters.file)) 
		return
	}

	; move files
	FileMove, % EvaluatedParameters.file, % EvaluatedParameters.destFile, % EvaluatedParameters.Overwrite
	
	; check for errors
	if errorlevel
	{
		; check whether destination file exists
		fileAttr := FileExist(EvaluatedParameters.destFile)
		if (not instr(fileAttr, "D") and not EvaluatedParameters.Overwrite)
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' already exists.", x_lang("Destination file"), EvaluatedParameters.destFile)) 
			return
		}

		; there was an other error
		x_finish(Environment, "exception", x_lang("%1% files could not be moved from '%2%' to '%3%'", errorlevel, EvaluatedParameters.file, EvaluatedParameters.destFile)) 
		return
	}
	
	x_finish(Environment,"normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Move_File(Environment, ElementParameters)
{
	
}






