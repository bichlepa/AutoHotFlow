﻿
;Name of the element
Element_getName_Action_Extract_files()
{
	return x_lang("Extract_files")
}

;Category of the element
Element_getCategory_Action_Extract_files()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Extract_files()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon file name which will be shown in the background of the element
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
	parametersToEdit.push({type: "File", id: "zipfile", label: x_lang("Select an archive"), filter: x_lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; .tbz2; .tbz; .tar; .z; .taz; .lzma)"})

	parametersToEdit.push({type: "Label", label: x_lang("Destination folder")})
	parametersToEdit.push({type: "Folder", id: "folder", label: x_lang("Select a folder")})

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Label", label: x_lang("Format"), size: "small"})
	parametersToEdit.push({type: "DropDown", id: "zipformat", default: "*", choices: ["*", "zip", "7z", "xz", "tar", "gzip", "BZIP2", "Z", "lzma"], result: "string"})
	
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
Element_CheckSettings_Action_Extract_files(Environment, ElementParameters, staticValues)
{
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Extract_files(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check whether folder exist
	fileAttr := FileExist(EvaluatedParameters.Folder)
	if (not fileAttr)
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Destination folder"), EvaluatedParameters.Folder)) 
		return
	}
	if (not instr(fileAttr, "D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is not a folder.", x_lang("Destination folder"), EvaluatedParameters.Folder)) 
		return
	}

	; check whether file exist
	fileAttr := FileExist(EvaluatedParameters.zipfile)
	if (not fileAttr)
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Source file"), EvaluatedParameters.zipfile)) 
		return
	}
	if (instr(fileAttr, "D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is a folder.", x_lang("Source file"), EvaluatedParameters.zipfile)) 
		return
	}

	; call 7zip
	result:=7z_extract(EvaluatedParameters.zipfile, "-t" EvaluatedParameters.zipformat, EvaluatedParameters.Folder)
	
	; check result and finish
	if (result = "Success")
		x_finish(Environment, "normal")
	else
		x_finish(Environment, "exception", result)
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Extract_files(Environment, ElementParameters)
{
	
}
