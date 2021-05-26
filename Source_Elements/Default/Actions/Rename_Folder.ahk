﻿;Always add this element class name to the global list
x_RegisterElementClass("Action_Rename_Folder")

;Element type of the element
Element_getElementType_Action_Rename_Folder()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Rename_Folder()
{
	return x_lang("Rename_Folder")
}

;Category of the element
Element_getCategory_Action_Rename_Folder()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Rename_Folder()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Rename_Folder()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Rename_Folder()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Rename_Folder()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Rename_Folder(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Source folder")})
	parametersToEdit.push({type: "Folder", id: "folder", label: x_lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: x_lang("Destination file or folder")})
	parametersToEdit.push({type: "Edit", id: "newName", default: x_lang("Renamed"), content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Rename_Folder(Environment, ElementParameters)
{
	return x_lang("Rename_Folder") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Rename_Folder(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Rename_Folder(Environment, ElementParameters)
{

	folderFrom := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.folder))

	newName := x_replaceVariables(Environment, ElementParameters.newName)

	if not FileExist(folderFrom)
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.",x_lang("Source folder"), folderFrom)) 
		return
	}
	if not newName
	{
		x_finish(Environment, "exception", x_lang("%1% is not specified.",x_lang("New folder name"))) 
		return
	}
	if (not instr(FileExist(fileFrom),"D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is not a folder.",x_lang("Source folder"), fileFrom)) 
		return
	}

	SplitPath,folderFrom,OldFolderName,folderOfFolderFrom
	newFolderPath:=folderOfFolderFrom "\" newName
	
	FileMoveDir,% fileFrom,% newFilePath,R
	
	if errorlevel ;Indecates that files could not be copied
	{
		x_finish(Environment, "exception", x_lang("Folder '%1%' could not be renamed to '%2%'",folderFrom, newFolderPath)) 
		return
	}
	
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Rename_Folder(Environment, ElementParameters)
{
	
}






