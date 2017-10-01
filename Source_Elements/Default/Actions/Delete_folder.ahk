;Always add this element class name to the global list
AllElementClasses.push("Action_Delete_Folder")

;Element type of the element
Element_getElementType_Action_Delete_Folder()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Delete_Folder()
{
	return lang("Delete_Folder")
}

;Category of the element
Element_getCategory_Action_Delete_Folder()
{
	return lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Delete_Folder()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Delete_Folder()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Delete_Folder()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Delete_Folder()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Delete_Folder()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Folder"})
	parametersToEdit.push({id: "ifEmpty"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Delete_Folder(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Source file")})
	parametersToEdit.push({type: "File", id: "Folder", label: lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: lang("Delete method")})
	parametersToEdit.push({type: "Checkbox", id: "ifEmpty", default: 0, label: lang("Remove only if the folder is empty")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Delete_Folder(Environment, ElementParameters)
{
	return lang("Delete_Folder") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Delete_Folder(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Delete_Folder(Environment, ElementParameters)
{
	OnlyIfEmpty := ElementParameters.ifEmpty

	Folder := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.Folder))

	if not FileExist(Folder)
	{
		x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("Folder"), Folder)) 
		return
	}

	if (OnlyIfEmpty)
	{
		FileRemoveDir,% Folder
	}
	else
	{
		FileRemoveDir,% Folder, 1
	}
	
	if errorlevel ;Indecates that files could not be copied
	{
		x_finish(Environment, "exception", lang("%1% folders could not be deleted (Filepattern: '%2%')",temperror, Folder)) 
		return
	}
	
	
	x_finish(Environment,"normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Delete_Folder(Environment, ElementParameters)
{
	
}






