;Always add this element class name to the global list
x_RegisterElementClass("Action_Write_To_File")

;Element type of the element
Element_getElementType_Action_Write_To_File()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Write_To_File()
{
	return x_lang("Write_To_File")
}

;Category of the element
Element_getCategory_Action_Write_To_File()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Write_To_File()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Write_To_File()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Write_To_File()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Write_To_File()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Write_To_File(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Text_to_write")})
	parametersToEdit.push({type: "Edit", id: "text", multiline: true, content: ["String", "Expression"], contentID: "Expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file"), options: 8})
	parametersToEdit.push({type: "Label", label: x_lang("Append or overwrite")})
	parametersToEdit.push({type: "Radio", id: "Overwrite", default: 1, choices: [x_lang("Append"), x_lang("Overwrite")], result: "enum", enum: ["Append", "Overwrite"]})
	parametersToEdit.push({type: "Label", label: x_lang("Encoding")})
	parametersToEdit.push({type: "Radio", id: "Encoding", default: "UTF-8", choices: [x_lang("System default ANSI codepage"), x_lang("Unicode UTF-8"), x_lang("Unicode UTF-16"), x_lang("Other")], result: "enum", enum: ["ansi", "UTF-8", "UTF-16", "other"]})
	parametersToEdit.push({type: "Checkbox", id: "WithBOM", default: 0, label: x_lang("Add byte order mark (BOM)")})
	parametersToEdit.push({type: "Edit", id: "CodePageIdentifier", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Linefeed")})
	parametersToEdit.push({type: "Checkbox", id: "Linefeed", default: 1, label: x_lang("Replace single linefeeds with carriage return and linefeed")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Write_To_File(Environment, ElementParameters)
{
	return x_lang("Write_To_File") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Write_To_File(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.encoding = "RAW")
	{
		x_Par_Disable("WithBOM")
		x_Par_Disable("Linefeed")
	}
	else
	{
		x_Par_Enable("Linefeed")
		if (ElementParameters.encoding = "UTF-8" or ElementParameters.encoding = "UTF-16")
		{
			x_Par_Enable("WithBOM")
		}
		else
		{
			x_Par_Disable("WithBOM")
		}
	}
	
	x_Par_Enable("CodePageIdentifier", ElementParameters.encoding = "other")
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Write_To_File(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	filepath := x_GetFullPath(Environment, EvaluatedParameters.file)
	
	
	if (EvaluatedParameters.encoding = "UTF-8" or EvaluatedParameters.encoding = "UTF-16")
	{
		if (EvaluatedParameters.WithBOM)
			FileEncoding,% EvaluatedParameters.encoding
		else
			FileEncoding,% EvaluatedParameters.encoding "-RAW"
	}
	else if (EvaluatedParameters.encoding = "ANSI")
	{
		FileEncoding ;Set system default ANSI codepage
	}
	else if (EvaluatedParameters.encoding = "other")
	{
		FileEncoding,% "CP" EvaluatedParameters.CodePageIdentifier
	}
	if (EvaluatedParameters.Linefeed)
	{
		pars.="*"
	}

	if (EvaluatedParameters.Overwrite = "Overwrite")
	{
		if (fileexist(filepath))
		{
			FileDelete,% filepath
			if errorlevel
			{
				x_finish(Environment, "exception",  x_lang("File '%1%' could not be deleted",filepath) )
				return
			}
		}
	}
	
	FileAppend,% EvaluatedParameters.text,% pars filepath
	
	if ErrorLevel
	{
		x_finish(Environment,"exception", x_lang("File '%1%' could not be written",filepath))
		return
	}
	
	x_finish(Environment,"normal")
	return
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Write_To_File(Environment, ElementParameters)
{
}






