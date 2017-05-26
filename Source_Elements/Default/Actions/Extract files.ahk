;Always add this element class name to the global list
AllElementClasses.push("Action_Extract_files")

Element_getPackage_Action_Extract_files()
{
	return "default"
}

Element_getElementType_Action_Extract_files()
{
	return "action"
}

Element_getName_Action_Extract_files()
{
	return lang("Extract_files")
}

Element_getIconPath_Action_Extract_files()
{
	;~ return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Extract_files()
{
	return lang("Files")
}

Element_getParameters_Action_Extract_files()
{
	return ["file", "zipfile", "zipformat"]
}

Element_getParametrizationDetails_Action_Extract_files(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Source archive")})
	parametersToEdit.push({type: "File", id: "zipfile", label: lang("Select a zip file"), filter: lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; tbz2; tbz; tar; .z; .taz; .lzma)"})
	parametersToEdit.push({type: "Label", label: lang("Destination folder")})
	parametersToEdit.push({type: "Folder", id: "folder", label: lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Label", label: lang("Format"), size: "small"})
	parametersToEdit.push({type: "DropDown", id: "zipformat", default: "*", choices: ["*", "7z", "zip", "xz", "tar", "gzip", "BZIP2", "Z", "lzma"], result: "string"})
	
	return parametersToEdit
}

Element_GenerateName_Action_Extract_files(Environment, ElementParameters)
{
	global
	return % lang("Extract_files") " - " ElementParameters.zipfile " - " ElementParameters.Folder
	
}

CheckSettingsActionExtract_files(ID)
{
	
}

Element_run_Action_Extract_files(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Folder := x_replaceVariables(Environment, ElementParameters.Folder)
	zipfile := x_replaceVariables(Environment, ElementParameters.zipfile)
	zipformat := ElementParameters.zipformat
	
	result:=7z_extract(zipfile, "-t" zipformat, Folder)
	if result = Success
		x_finish(Environment, "normal")
	else
		x_finish(Environment, "exception", result)
}
