;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_file_attributes")

;Element type of the element
Element_getElementType_Action_Set_file_attributes()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_file_attributes()
{
	return x_lang("Set_file_attributes")
}

;Category of the element
Element_getCategory_Action_Set_file_attributes()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_file_attributes()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_file_attributes()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Set_file_attributes()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_file_attributes()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_file_attributes(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Select file")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file")})

	parametersToEdit.push({type: "Label", label: x_lang("Attributes")})
	parametersToEdit.push({type: "CheckBox", id: "ReadOnly", default: -1, label: x_lang("Read only"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Archive", default: -1, label: x_lang("Archive"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "System", default: -1, label: x_lang("System"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Hidden", default: -1, label: x_lang("Hidden"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Offline", default: -1, label: x_lang("Offline"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Temporary", default: -1, label: x_lang("Temporary"), gray: true})

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Radio", id: "OperateOnWhat", default: 1, choices: [x_lang("Operate on files"), x_lang("Operate on files and folders"), x_lang("Operate on folders")], result: "enum", enum: ["Files", "FilesAndFolders", "Folders"]})
	parametersToEdit.push({type: "Checkbox", id: "Recurse", default: 0, label: x_lang("Recurse subfolders into")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_file_attributes(Environment, ElementParameters)
{
	return x_lang("Set_file_attributes") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_file_attributes(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_file_attributes(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; prepare attributes string for FileSetAttrib
	newAttributes := ""
	if (EvaluatedParameters.ReadOnly = 1)
		newAttributes .= "+R"
	else if (EvaluatedParameters.ReadOnly = 0)
		newAttributes .= "-R"
	if (EvaluatedParameters.Archive = 1)
		newAttributes .= "+A"
	else if (EvaluatedParameters.Archive = 0)
		newAttributes .= "-A"
	if (EvaluatedParameters.System = 1)
		newAttributes .= "+S"
	else if (EvaluatedParameters.System = 0)
		newAttributes .= "-S"
	if (EvaluatedParameters.Hidden = 1)
		newAttributes .= "+H"
	else if (EvaluatedParameters.Hidden = 0)
		newAttributes .= "-H"
	if (EvaluatedParameters.Offline = 1)
		newAttributes .= "+O"
	else if (EvaluatedParameters.Offline = 0)
		newAttributes .= "-O"
	if (EvaluatedParameters.Temporary = 1)
		newAttributes .= "+T"
	else if (EvaluatedParameters.Temporary = 0)
		newAttributes .= "-T"
	
	; prepare operation string for FileSetAttrib
	if (EvaluatedParameters.OperateOnWhat = "Files")
		operation := 0
	else if (EvaluatedParameters.OperateOnWhat = "FilesAndFolders")
		operation := 1
	else if (EvaluatedParameters.OperateOnWhat = "Folders")
		operation := 2

	; set new file attributes
	FileSetAttrib, % newAttributes, % EvaluatedParameters.file, % operation, % EvaluatedParameters.Recurse

	; check for errors
	if ErrorLevel
	{
		; we check here whether file exists, because the file path may contain a wildcard pattern
		if not fileexist(EvaluatedParameters.file)
		{
			x_finish(Environment, "exception", x_lang("File '%1%' does not exist", EvaluatedParameters.file))
			return
		}
		else
		{
			x_finish(Environment, "exception", x_lang("Attributes of file '%1%' could not be changed", EvaluatedParameters.file)) 
			return
		}
	}
	
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_file_attributes(Environment, ElementParameters)
{
}






