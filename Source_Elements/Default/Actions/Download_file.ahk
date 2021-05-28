;Always add this element class name to the global list
x_RegisterElementClass("Action_Download_File")

;Element type of the element
Element_getElementType_Action_Download_File()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Download_File()
{
	return x_lang("Download_File")
}

;Category of the element
Element_getCategory_Action_Download_File()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Download_File()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Download_File()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Download_File()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Download_File()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Download_File(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("URL")})
	parametersToEdit.push({type: "Edit", id: "URL", default: "http://www.example.com", content: ["RawString", "String", "Expression"], contentID: "IsExpression", contentDefault: "string", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select file"), default: "%A_Desktop%\Downloaded example.html"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Download_File(Environment, ElementParameters)
{
	return x_lang("Download_File") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Download_File(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Download_File(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check whether destination file path is a folder
	fileAttr := FileExist(EvaluatedParameters.file)
	if (instr(fileAttr, "D"))
	{
		x_finish(Environment, "exception", x_lang("%1% '%2%' is a folder.", x_lang("Destination file"), EvaluatedParameters.file)) 
		return
	}

	; download file
	URLDownloadToFile, % EvaluatedParameters.URL, % EvaluatedParameters.file

	; check for errors
	if ErrorLevel
	{
		x_finish(Environment, "exception", x_lang("Couldn't download URL '%1%' to file '%2%", EvaluatedParameters.URL, EvaluatedParameters.file))
		return
	}

	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Download_File(Environment, ElementParameters)
{
	
}






