;Always add this element class name to the global list
x_RegisterElementClass("Action_Delete_File")

;Element type of the element
Element_getElementType_Action_Delete_File()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Delete_File()
{
	return lang("Delete_File")
}

;Category of the element
Element_getCategory_Action_Delete_File()
{
	return lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Delete_File()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Delete_File()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Delete_File()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Delete_File()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Delete_File()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "file"})
	parametersToEdit.push({id: "deleteFileMethod"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Delete_File(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Source file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("Delete method")})
	parametersToEdit.push({type: "Radio", id: "deleteFileMethod", default: "Recycle", result: "enum", choices: [lang("Delete"), lang("Recycle")], enum: ["Delete", "Recycle"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Delete_File(Environment, ElementParameters)
{
	return lang("Delete_File") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Delete_File(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Delete_File(Environment, ElementParameters)
{
	deleteFileMethod := ElementParameters.deleteFileMethod

	file := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))

	if not FileExist(file)
	{
		x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("File"), file)) 
		return
	}

	if (deleteFileMethod = "Delete")
	{
		FileDelete,% file
		
		if errorlevel ;Indecates that files could not be copied
		{
			x_finish(Environment, "exception", lang("%1% files could not be deleted (Filepattern: '%2%')",temperror, file)) 
			return
		}
	}
	else if (deleteFileMethod = "Recycle") 
	{
		FileRecycle, % file
		if errorlevel ;Indecates that files could not be copied
		{
			x_finish(Environment, "exception", lang("Some files could not be recycled (Filepattern: '%2%')",temperror, file)) 
			return
		}
	}
	
	
	x_finish(Environment,"normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Delete_File(Environment, ElementParameters)
{
	
}






