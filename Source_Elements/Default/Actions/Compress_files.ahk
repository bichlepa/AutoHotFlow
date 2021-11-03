
;Name of the element
Element_getName_Action_Compress_files()
{
	return x_lang("Compress_files")
}

;Category of the element
Element_getCategory_Action_Compress_files()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Compress_files()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Compress_files()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Compress_files()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Compress_files(Environment)
{
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("Source file")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file")})

	parametersToEdit.push({type: "Label", label: x_lang("Destination archive")})
	parametersToEdit.push({type: "File", id: "zipfile", label: x_lang("Select a file path for the compressed file"), filter: x_lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; .tbz2; .tbz; .tar)", options: "S"})

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Label", label: x_lang("Format"), size: "small"})
	parametersToEdit.push({type: "DropDown", id: "zipformat", default: "zip", choices: ["zip", "7z", "xz", "tar", "gzip", "BZIP2"], result: "string"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Compress_files(Environment, ElementParameters)
{
	global
	return % x_lang("Compress_files") " - " ElementParameters.zipformat " - " ElementParameters.file " - " ElementParameters.zipfile
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Compress_files(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Compress_files(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check whether zip file path is a folder
	fileAttr := FileExist(EvaluatedParameters.zipfile)
	if (instr(fileAttr, "D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is a folder.", x_lang("Destination file"), EvaluatedParameters.zipfile)) 
		return
	}
	
	; call 7zip
	result := 7z_compress(EvaluatedParameters.zipfile, "-t" EvaluatedParameters.zipformat, EvaluatedParameters.File)

	; check result and finish
	if (result = "Success")
		x_finish(Environment, "normal")
	else
		x_finish(Environment, "exception", result)
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Compress_files(Environment, ElementParameters)
{
	
}