;Always add this element class name to the global list
AllElementClasses.push("Action_Compress_files")

Element_getPackage_Action_Compress_files()
{
	return "default"
}

Element_getElementType_Action_Compress_files()
{
	return "action"
}

Element_getElementLevel_Action_Compress_files()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

Element_getName_Action_Compress_files()
{
	return lang("Compress_files")
}

Element_getIconPath_Action_Compress_files()
{
	;~ return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Compress_files()
{
	return lang("Files")
}

Element_getParameters_Action_Compress_files()
{
	return ["file", "zipfile", "zipformat"]
}

Element_getParametrizationDetails_Action_Compress_files(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Source file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("Destination archive")})
	parametersToEdit.push({type: "File", id: "zipfile", label: lang("Select a zip file"), filter: lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; tbz2; tbz; tar)", options: "S"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Label", label: lang("Format"), size: "small"})
	parametersToEdit.push({type: "DropDown", id: "zipformat", default: "*", choices: ["*", "7z", "zip", "xz", "tar", "gzip", "BZIP2"], result: "string"})
	
	return parametersToEdit
}

Element_GenerateName_Action_Compress_files(Environment, ElementParameters)
{
	global
	return % lang("Compress_files") " - " ElementParameters.file " - " ElementParameters.zipfile
	
}

CheckSettingsActionCompress_files(ID)
{
	
}

Element_run_Action_Compress_files(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	File := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.File))
	zipfile := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.zipfile))
	zipformat := ElementParameters.zipformat
	
	result:=7z_compress(zipfile, "-t" zipformat, file)
	if result = Success
		x_finish(Environment, "normal")
	else
		x_finish(Environment, "exception", result)
}
