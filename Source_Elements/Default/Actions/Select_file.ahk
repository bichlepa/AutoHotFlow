;Always add this element class name to the global list
x_RegisterElementClass("Action_Select_file")

;Element type of the element
Element_getElementType_Action_Select_file()
{
	return "action"
}

;Name of the element
Element_getName_Action_Select_file()
{
	return x_lang("Select_file")
}

;Category of the element
Element_getCategory_Action_Select_file()
{
	return x_lang("User_interaction") "|" x_lang("Files")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Select_file()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Select_file()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Select_file()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Select_file()
{
	;"Stable" or "Experimental"
	return "Experimental"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Select_file(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "selectedFiles", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Prompt")})
	parametersToEdit.push({type: "Edit", id: "title", default: x_lang("Select a file"), content: "String"})

	parametersToEdit.push({type: "Label", label: x_lang("Root directory")})
	parametersToEdit.push({type: "folder", id: "folder"})

	parametersToEdit.push({type: "Label", label: x_lang("Filter")})
	parametersToEdit.push({type: "Edit", id: "filter", default: x_lang("Any files") " (*.*)", content: "String"})

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "checkbox", id: "MultiSelect", default: 0, label: x_lang("Allow to select multiple files")})
	parametersToEdit.push({type: "checkbox", id: "SaveButton", default: 0, label: x_lang("'Save' button instead of an 'Open' button")})
	parametersToEdit.push({type: "checkbox", id: "fileMustExist", default: 0, label: x_lang("File must exist")})
	parametersToEdit.push({type: "checkbox", id: "PathMustExist", default: 0, label: x_lang("Path must exist")})
	parametersToEdit.push({type: "checkbox", id: "PromptNewFile", default: 0, label: x_lang("Prompt to create new file")})
	parametersToEdit.push({type: "checkbox", id: "PromptOverwriteFile", default: 0, label: x_lang("Prompt to overwrite file")})
	parametersToEdit.push({type: "checkbox", id: "NoShortcutTarget", default: 0, label: x_lang("Don't resolve shortcuts to their targets")})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Select_file(Environment, ElementParameters)
{
	global
	return % x_lang("Select_file") " - " ElementParameters.varname " - " ElementParameters.folder
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Select_file(Environment, ElementParameters, staticValues)
{
	if (ElementParameters.MultiSelect = True)
	{
		x_Par_Disable("SaveButton")
		x_Par_SetValue("SaveButton", False)
	}
	else
	{
		x_Par_Enable("SaveButton")
	}
	if (ElementParameters.SaveButton = True)
	{
		x_Par_Disable("fileMustExist")
		x_Par_SetValue("fileMustExist", False)
	}
	else
	{
		x_Par_Enable("fileMustExist")
	}
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Select_file(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get absolute path
	folder := x_GetFullPath(Environment, EvaluatedParameters.folder)
	
	; prepare options for FileSelectFile
	options := 0
	if (ElementParameters.fileMustExist)
		options += 1
	if (ElementParameters.PathMustExist)
		options += 2
	if (ElementParameters.PromptNewFile)
		options += 8
	if (ElementParameters.PromptOverwriteFile)
		options += 16
	if (ElementParameters.NoShortcutTarget)
		options += 32
	if (ElementParameters.SaveButton)
		options := "S" options
	if (ElementParameters.MultiSelect)
		options := "M" options
	
	; we will call FileSelectFile in an other AHK thread, because the dialog is blocking.
	; set input and output variables
	inputVars := {options: options, folder: folder, title: title, filter: filter}
	outputVars := ["selectedFile", "result", "message"]

	; define code of the AHK thread
	code =
	( ` , LTrim %
	
		FileSelectFile, selectedFile, %options%, %folder%, %title%, %filter%
		if errorlevel
		{
			result := "exception"
			message := "User dismissed the dialog without selecting a file or system refused to show the dialog."
		}
		else
		{
			IfInString, options, m ;If multiselect, make a list
			{
				selectedFileCopy := selectedFile
				selectedFile := Object()
				Loop, parse, selectedFileCopy, `n
				{
					if (a_index = 1)
						tempActionSelectFiledir := A_LoopField
					else
						selectedFile.push(tempActionSelectFiledir "\" A_LoopField )
					
				}
			}
			
			result := "normal"
		}
	)
	; make sure, lang crawler finds the translation for the error message
	; x_lang("User dismissed the dialog without selecting a file or system refused to show the dialog.")
	
	; start new AHK thread
	functionObject := x_NewFunctionObject(Environment, "Action_Select_file_FinishExecution", ElementParameters, EvaluatedParameters.Varname)
	x_ExecuteInNewAHKThread(Environment, functionObject, code, inputVars, outputVars)
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Select_file(Environment, ElementParameters)
{
	; stop the other AHK thread
	x_ExecuteInNewAHKThread_Stop(Environment)
}


; callback function of the external thread
Action_Select_file_FinishExecution(Environment, ElementParameters, Varname, outputVars)
{
	; check result
	if (outputVars.result = "normal")
	{
		; user selected a file
		; set output variable
		x_SetVariable(Environment, Varname, outputVars.selectedFile)
		; finish
		x_finish(Environment, outputVars.result)
	}
	else
	{
		; user did not select a file
		x_finish(Environment, "exception", outputVars.message)
	}
}
