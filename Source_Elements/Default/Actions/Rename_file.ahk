;Always add this element class name to the global list
x_RegisterElementClass("Action_Rename_File")

;Element type of the element
Element_getElementType_Action_Rename_File()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Rename_File()
{
	return x_lang("Rename_File")
}

;Category of the element
Element_getCategory_Action_Rename_File()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Rename_File()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Rename_File()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Rename_File()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Rename_File()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Rename_File(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Source file")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file")})
	parametersToEdit.push({type: "Label", label: x_lang("New file name")})
	parametersToEdit.push({type: "Edit", id: "newName", default: x_lang("Renamed") ".txt", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Overwrite")})
	parametersToEdit.push({type: "Checkbox", id: "Overwrite", default: 0, label: x_lang("Overwrite existing files")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Rename_File(Environment, ElementParameters)
{
	return x_lang("Rename_File") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Rename_File(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Rename_File(Environment, ElementParameters)
{

	Overwrite := ElementParameters.Overwrite

	fileFrom := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))

	newName := x_replaceVariables(Environment, ElementParameters.newName)

	if not FileExist(fileFrom)
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.",x_lang("Source file"), fileFrom)) 
		return
	}
	if not newName
	{
		x_finish(Environment, "exception", x_lang("%1% is not specified.",x_lang("New file name"))) 
		return
	}
	if (instr(FileExist(fileFrom),"D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is a folder.",x_lang("Source file"), fileFrom)) 
		return
	}

	SplitPath,fileFrom,OldFileName,folderFrom
	newFilePath:=folderFrom "\" newName
	
	FileMove,% fileFrom,% newFilePath,% Overwrite
	
	;Todo: check whether error handling is correct
	if a_lasterror ;Indicates that no files were found
	{
		if errorlevel ;Indecates that files could not be copied
		{
			x_finish(Environment, "exception", x_lang("%1% files could not be renamed from '%2%' to '%3%'",temperror, fileFrom, newFilePath)) 
			return
		}
		else
		{
			x_finish(Environment, "exception", x_lang("No files found (%1%)", fileFrom)) 
			return
		}
	}
	else
	{
		if errorlevel ;Indecates that files could not be copied
		{
			x_finish(Environment, "exception", x_lang("%1% files could not be renamed from '%2%' to '%3%'",temperror, fileFrom, newFilePath)) 
			return
		}
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Rename_File(Environment, ElementParameters)
{
	
}

