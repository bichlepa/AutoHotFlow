
;Name of the element
Element_getName_Action_Create_Folder()
{
	return x_lang("Create_Folder")
}

;Category of the element
Element_getCategory_Action_Create_Folder()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Create_Folder()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Create_Folder()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Create_Folder()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Create_Folder(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Source folder")})
	parametersToEdit.push({type: "File", id: "folder", label: x_lang("Select a folder")})

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "ErrorIfExists", default: 0, label: x_lang("Throw exception if folder already exists")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Create_Folder(Environment, ElementParameters)
{
	return x_lang("Create_Folder") " - " ElementParameters.folder
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Create_Folder(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Create_Folder(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check whether path exists
	fileAttr := FileExist(EvaluatedParameters.folder)
	if (fileAttr)
	{
		if (not instr(fileAttr, "D"))
		{
			; there is a file in that path
			x_finish(Environment, "exception", x_lang("%1% '%2%' exists and it is a file.", x_lang("Destination folder"), EvaluatedParameters.folder)) 
			return
		}
		Else
		{
			; folder already exists
			if (EvaluatedParameters.ErrorIfExists)
			{
				; ErrorIfExists is set. Throw exception
				x_finish(Environment, "exception", x_lang("%1% '%2%' already exists.", x_lang("Destination folder"), EvaluatedParameters.folder))
			}
			; folder already exists and ErrorIfExists is not set . Nothing to do.
			x_finish(Environment,"normal")
			return
		}
	}

	; create directory
	FileCreateDir, % EvaluatedParameters.folder

	; check for errors
	if errorlevel 
	{
		x_finish(Environment, "exception", x_lang("Folder '%1%' could not be created", EvaluatedParameters.folder)) 
		return
	}
	
	; no errors occured. finish normally
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Create_Folder(Environment, ElementParameters)
{
	
}






