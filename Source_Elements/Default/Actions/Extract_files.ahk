;Always add this element class name to the global list
x_RegisterElementClass("Action_Extract_files")

;Element type of the element
Element_getElementType_Action_Extract_files()
{
	return "action"
}

;Name of the element
Element_getName_Action_Extract_files()
{
	return x_lang("Extract_files")
}

;Category of the element
Element_getCategory_Action_Extract_files()
{
	return x_lang("Files")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Extract_files()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Extract_files()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Extract_files()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Extract_files()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Extract_files(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Source archive")})
	parametersToEdit.push({type: "File", id: "zipfile", label: x_lang("Select a zip file"), filter: x_lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; tbz2; tbz; tar; .z; .taz; .lzma)"})
	parametersToEdit.push({type: "Label", label: x_lang("Destination folder")})
	parametersToEdit.push({type: "Folder", id: "folder", label: x_lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Label", label: x_lang("Format"), size: "small"})
	parametersToEdit.push({type: "DropDown", id: "zipformat", default: "*", choices: ["*", "7z", "zip", "xz", "tar", "gzip", "BZIP2", "Z", "lzma"], result: "string"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Extract_files(Environment, ElementParameters)
{
	global
	return % x_lang("Extract_files") " - " ElementParameters.zipfile " - " ElementParameters.Folder
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Extract_files(Environment, ElementParameters)
{
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Extract_files(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Folder := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.Folder))
	zipfile := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.zipfile))
	zipformat := ElementParameters.zipformat
	
	result:=7z_extract(zipfile, "-t" zipformat, Folder)
	if result = Success
		x_finish(Environment, "normal")
	else
		x_finish(Environment, "exception", result)
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Extract_files(Environment, ElementParameters)
{
	
}
