;Always add this element class name to the global list
AllElementClasses.push("Action_Select_Folder")

Element_getPackage_Action_Select_Folder()
{
	return "default"
}

Element_getElementType_Action_Select_Folder()
{
	return "action"
}

Element_getElementLevel_Action_Select_Folder()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Select_Folder()
{
	return lang("Select_Folder")
}

Element_getIconPath_Action_Select_Folder()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Select_Folder()
{
	return lang("User_interaction") "|" lang("Files")
}

Element_getParameters_Action_Select_Folder()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Varname"})
	parametersToEdit.push({id: "title"})
	parametersToEdit.push({id: "folder"})
	parametersToEdit.push({id: "AllowUpward"})
	parametersToEdit.push({id: "ButtonNewFolder"})
	parametersToEdit.push({id: "EditField"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Action_Select_Folder(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "selectedFolder", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Prompt")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Select a folder"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Root directory")})
	parametersToEdit.push({type: "folder", id: "folder"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "checkbox", id: "AllowUpward", default: 1, label: lang("Permit to navigate upward")})
	parametersToEdit.push({type: "checkbox", id: "ButtonNewFolder", default: 0, label: lang("Show a button to create a new folder")})
	parametersToEdit.push({type: "checkbox", id: "EditField", default: 0, label: lang("Show an edit field to type in the folder name")})

	return parametersToEdit
}

Element_GenerateName_Action_Select_Folder(Environment, ElementParameters)
{
	global
	return % lang("Select_Folder") " - " ElementParameters.varname " - " ElementParameters.folder
	
}

CheckSettingsActionSelect_Folder(ID)
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

Element_run_Action_Select_Folder(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	if not x_CheckVariableName(varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varname)))
		return
	}
	
	title := x_replaceVariables(Environment, ElementParameters.title)
	folder := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.folder))
	
	options:=0
	if (ElementParameters.ButtonNewFolder)
		options+=1
	if (ElementParameters.EditField)
		options+=2
	if (ElementParameters.AllowUpward)
		folder:="*" folder
	
	inputVars:={options: options, folder: folder, title: title}
	outputVars:=["selectedFolder", "result", "message"]
	code =
	( ` , LTrim %
	
		FileSelectFolder,selectedFolder,%folder%,%options%,%title%
		if errorlevel
		{
			result := "exception"
			message := "User dismissed the dialog without selecting a folder or system refused to show the dialog."
		}
		else
		{
			result := "normal"
		}
	)
	;Translations: lang("User dismissed the dialog without selecting a file or system refused to show the dialog.")
	
	functionObject := x_NewExecutionFunctionObject(Environment, "Action_Select_Folder_FinishExecution", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	x_SetExecutionValue(Environment, "Varname", Varname)
	x_ExecuteInNewAHKThread(Environment, functionObject, code, inputVars, outputVars)
}

Action_Select_Folder_FinishExecution(Environment, values, ElementParameters)
{
	;~ d(values,"asdf")
	;~ d(ElementParameters,"asdf")
	
	if (values.result="normal")
	{
		varname := x_GetExecutionValue(Environment, "Varname")
		x_SetVariable(Environment, Varname, values.selectedFolder)
		x_finish(Environment,values.result, values.message)
	}
	else
	{
		x_finish(Environment,"exception", values.message)
	}
	
}
