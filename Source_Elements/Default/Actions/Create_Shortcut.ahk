
;Name of the element
Element_getName_Action_Create_Shortcut()
{
	return x_lang("Create shortcut")
}

;Category of the element
Element_getCategory_Action_Create_Shortcut()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Create_Shortcut()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Create_Shortcut()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Create_Shortcut()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Create_Shortcut(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Shortcut path")})
	parametersToEdit.push({type: "File", id: "shortcutFile", default: "shortcut.lnk", label: x_lang("Select a shortcut file"), filter: x_lang("Shortcut file") " (*.lnk)", options: 32, warnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Target path")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a target file"), warnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Target arguments")})
	parametersToEdit.push({type: "Edit", id: "runArguments", content: ["String", "RawString"], contentID: "ToRunContent", contentDefault: "string"})

	parametersToEdit.push({type: "Label", label: x_lang("Working directory")})
	parametersToEdit.push({type: "Folder", id: "WorkingDir", label: x_lang("Select a folder")})

	parametersToEdit.push({type: "Label", label: x_lang("Description")})
	parametersToEdit.push({type: "Edit", id: "description", content: "String"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Icon path")})
	parametersToEdit.push({type: "File", id: "iconFile", label: x_lang("Select an icon"), options: 8, filter: x_lang("File with icon") " (*.ico; *.exe; *.dll)"})
	parametersToEdit.push({type: "Label", label: x_lang("File with multiple icons"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "SetIconNumber", default: 0, label: x_lang("Set icon number")})
	parametersToEdit.push({type: "Edit", id: "IconNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Run mode")})
	parametersToEdit.push({type: "Radio", id: "RunMode", default: "Normal", result: "enum", choices: [x_lang("Run normally"), x_lang("Run maximized"), x_lang("Run minimized")], enum: ["Normal", "Max", "Min"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Create_Shortcut(Environment, ElementParameters)
{
	return x_lang("Create shortcut") " - " ElementParameters.shortcutFile " - " ElementParameters.file " " ElementParameters.runArguments
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Create_Shortcut(Environment, ElementParameters, staticValues)
{	
	if not (ElementParameters.iconFile)
	{
		x_Par_Disable("SetIconNumber")
		x_Par_Disable("IconNumber")
	}
	Else
	{
		x_Par_Enable("SetIconNumber")
		x_Par_Enable("IconNumber", ElementParameters.SetIconNumber)
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Create_Shortcut(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["WorkingDir", "iconFile", "IconNumber"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	switch EvaluatedParameters.RunMode
	{
		case "Normal":
		runmodePar := 1
		case "Max":
		runmodePar := 3
		case "Min":
		runmodePar := 7
	}

	if (ElementParameters.WorkingDir)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["WorkingDir"])
	}
	if (ElementParameters.iconFile)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["iconFile"])
		if (ElementParameters.SetIconNumber)
		{
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["IconNumber"])
		}
	}

	; chreate the shortcut
	FileCreateShortcut, % EvaluatedParameters.file, % EvaluatedParameters.shortcutFile, % EvaluatedParameters.WorkingDir, % EvaluatedParameters.runArguments, % EvaluatedParameters.description, % EvaluatedParameters.iconFile, , % EvaluatedParameters.IconNumber, % runmodePar

	; check for errors
	if (ErrorLevel)
	{
		x_finish(Environment, "exception", x_lang("Can't create shortcut '%1%'", EvaluatedParameters.shortcutFile))
		return
	}

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Create_Shortcut(Environment, ElementParameters)
{
}



