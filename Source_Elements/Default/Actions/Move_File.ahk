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
	return lang("Move_File")
}

;Category of the element
Element_getCategory_Action_Move_File()
{
	return lang("File")
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
	
	parametersToEdit.push({type: "Label", label: lang("Source file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("Destination file or folder")})
	parametersToEdit.push({type: "Folder", id: "destFile", label: lang("Select a file or folder")})
	parametersToEdit.push({type: "Label", label: lang("Overwrite")})
	parametersToEdit.push({type: "Checkbox", id: "Overwrite", default: 0, label: lang("Overwrite existing files")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Move_File(Environment, ElementParameters)
{
	return lang("Move_File") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Move_File(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Move_File(Environment, ElementParameters)
{

	Overwrite := ElementParameters.Overwrite

	fileFrom := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))

	destFileOrFolder := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.destFile))

	if not FileExist(fileFrom)
	{
		x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("Source file"), fileFrom)) 
		return
	}
	if not FileExist(destFileOrFolder)
	{
		x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("Destination file or folder"), destFileOrFolder)) 
		return
	}

	FileMove,% fileFrom,% destFileOrFolder,% Overwrite
	;Todo: check whether error handling is correct
	if a_lasterror ;Indicates that no files were found
	{
		if errorlevel ;Indecates that files could not be copied
		{
			x_finish(Environment, "exception", lang("%1% files could not be moved from '%2%' to '%3%'",temperror, fileFrom, destFileOrFolder)) 
			return
		}
		else
		{
			x_finish(Environment, "exception", lang("No files found (%1%)", fileFrom)) 
			return
		}
	}
	else
	{
		if errorlevel ;Indecates that files could not be copied
		{
			x_finish(Environment, "exception", lang("%1% files could not be moved from '%2%' to '%3%'",temperror, fileFrom, destFileOrFolder)) 
			return
		}
	}
	
	
	x_finish(Environment,"normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Move_File(Environment, ElementParameters)
{
	
}






