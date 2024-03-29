﻿
;Name of the element
Element_getName_Action_Copy_Folder()
{
	return x_lang("Copy_Folder")
}

;Category of the element
Element_getCategory_Action_Copy_Folder()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Copy_Folder()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Copy_Folder()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Copy_Folder()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Copy_Folder(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Source folder")})
	parametersToEdit.push({type: "Folder", id: "folder", label: x_lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: x_lang("Destination file or folder")})
	parametersToEdit.push({type: "Folder", id: "destFolder", label: x_lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: x_lang("Overwrite")})
	parametersToEdit.push({type: "Checkbox", id: "Overwrite", default: 0, label: x_lang("Overwrite existing files")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Copy_Folder(Environment, ElementParameters)
{
	return x_lang("Copy_Folder") " - " ElementParameters.folder " - " ElementParameters.destFolder
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Copy_Folder(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Copy_Folder(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check whether source folder exists
	fileAttr := FileExist(EvaluatedParameters.folder)
	if (not fileAttr)
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Source folder"), ElementParameters.folder)) 
		return
	}
	if (not instr(fileAttr, "D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is not a folder.", x_lang("Source folder"), ElementParameters.folder)) 
		return
	}
	
	; check whether desination folder exists
	fileAttr := FileExist(EvaluatedParameters.destFolder)
	if (fileAttr)
	{
		if (not EvaluatedParameters.Overwrite)
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' already exists.", x_lang("Destination folder"), ElementParameters.destFolder)) 
			return
		}
		else if (not instr(fileAttr, "D"))
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' exists and is not a folder.", x_lang("Destination folder"), ElementParameters.destFolder)) 
			return
		}
	}

	; copy folder
	FileCopyDir, % EvaluatedParameters.folder, % EvaluatedParameters.destFolder, % EvaluatedParameters.Overwrite

	; check for errors
	if errorlevel ;Indecates that files could not be copied
	{
		x_finish(Environment, "exception", x_lang("Folder '%1%' could not be copied to '%2%'", EvaluatedParameters.folder, EvaluatedParameters.destFolder)) 
		return
	}
	
	; no errors occured. finish normally
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Copy_Folder(Environment, ElementParameters)
{
	
}






