;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_file_time")

;Element type of the element
Element_getElementType_Action_Set_file_time()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_file_time()
{
	return x_lang("Set_file_time")
}

;Category of the element
Element_getCategory_Action_Set_file_time()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_file_time()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_file_time()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Set_file_time()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_file_time()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_file_time(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("New time") " (" x_lang("Date format") ")"})
	parametersToEdit.push({type: "Edit", id: "time", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Select file")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file"), options: 8})
	parametersToEdit.push({type: "Label", label: x_lang("Which time")})
	parametersToEdit.push({type: "Radio", id: "TimeType", result: "enum", default: 1, choices: [x_lang("Modification time"), x_lang("Creation time"), x_lang("Last access time")], enum: ["Modification", "Creation", "Access"]})
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Radio", id: "OperateOnWhat", default: 1, choices: [x_lang("Operate on files"), x_lang("Operate on files and folders"), x_lang("Operate on folders")], result: "enum", enum: ["Files", "FilesAndFolders", "Folders"]})
	parametersToEdit.push({type: "Checkbox", id: "Recurse", default: 0, label: x_lang("Recurse subfolders into")})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_file_time(Environment, ElementParameters)
{
	return x_lang("Set_file_time") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_file_time(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_file_time(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	temptime:=ElementParameters.time
	
	if temptime is not time
	{
		x_finish(Environment, "exception", x_lang("Timestamp '%1%' is not valid", temptime)) 
		return
	}
	
	TimeType:=ElementParameters.Unit
	if (TimeType = "Modification")
		TimeTypePar:="M"
	else if (TimeType = "Creation")
		TimeTypePar :="C"
	else if (TimeType = "Access")
		TimeTypePar :="A"

	
	tempPath:= x_GetFullPath(Environment,EvaluatedParameters.file)
	
	
	FileSetTime,%temptime%,% tempPath,%TimeTypePar%
	if ErrorLevel
	{
		if not fileexist(tempPath)
		{
			x_finish(Environment, "exception", x_lang("File '%1%' does not exist",tempPath))
			return
		}
		else
		{
			x_finish(Environment, "exception", x_lang("Attributes of file '%1%' could not be changed",tempPath)) 
			return
		}
	}
	x_finish(Environment,"normal")
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_file_time(Environment, ElementParameters)
{
}






