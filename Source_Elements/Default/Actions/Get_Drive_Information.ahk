
;Name of the element
Element_getName_Action_Get_Drive_Information()
{
	return x_lang("Get_Drive_Information")
}

;Category of the element
Element_getCategory_Action_Get_Drive_Information()
{
	return x_lang("Drive")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Drive_Information()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Get_Drive_Information()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Drive_Information()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Drive_Information(Environment)
{
	parametersToEdit:=Object()
	
	; get list of drive letters
	listOfdrives := Object()
	driveget, tempdrives,list
	
	loop, parse, tempdrives
	{
		if (a_index = 1)
			defaultdrive := A_LoopField ":"
		listOfdrives.push(A_LoopField ":")
	}
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "DriveInfo", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Which information")})
	parametersToEdit.push({type: "dropdown", id: "WhichInformation", default: "Label", result: "enum", choices: [x_lang("Label"), x_lang("Type"), x_lang("Status"), x_lang("Status of optical disc drive"), x_lang("Capacity"), x_lang("Free disk space"), x_lang("File system"), x_lang("Serial number")], enum: ["Label", "Type", "Status", "StatusCD", "Capacity", "FreeSpace", "FileSystem", "Serial"] })
	
	parametersToEdit.push({type: "Label", label: x_lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultdrive, choices: listOfdrives})
	
	parametersToEdit.push({type: "Label", label: x_lang("Path")})
	parametersToEdit.push({type: "Folder", id: "folder", label: x_lang("Select a folder")})
	
	; request that the result of this function is never cached (because of the drive letter list)
	parametersToEdit.updateOnEdit := true
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Drive_Information(Environment, ElementParameters)
{
	
	WhichInformation := ElementParameters.WhichInformation
	if  (WhichInformation = "Label" or WhichInformation = "StatusCD" or WhichInformation = "FileSystem" or WhichInformation = "Serial")
	{
		pathString := ElementParameters.DriveLetter
	}
	else if (WhichInformation = "Type" or WhichInformation = "Capacity" or WhichInformation = "FreeSpace")
	{
		pathString := ElementParameters.folder
	}

	switch (ElementParameters.WhichInformation)
	{
		case "Label":
		WhichInformationString := x_lang("Label")
		case "Type":
		WhichInformationString := x_lang("Type")
		case "Status":
		WhichInformationString := x_lang("Status")
		case "StatusCD":
		WhichInformationString := x_lang("Status of optical disc drive")
		case "Capacity":
		WhichInformationString := x_lang("Capacity")
		case "FreeSpace":
		WhichInformationString := x_lang("Free disk space")
		case "FileSystem":
		WhichInformationString := x_lang("File system")
		case "Serial":
		WhichInformationString := x_lang("Serial number")
	}

	return x_lang("Get_Drive_Information") " - " ElementParameters.DriveInfo " - " WhichInformationString " - " pathString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Drive_Information(Environment, ElementParameters, staticValues)
{	
	WhichInformation := ElementParameters.WhichInformation
	if  (WhichInformation = "Label" or WhichInformation = "StatusCD" or WhichInformation = "FileSystem" or WhichInformation = "Serial")
	{
		x_par_enable("DriveLetter")
		x_par_disable("folder")
	}
	else if (WhichInformation = "Type" or WhichInformation = "Capacity" or WhichInformation = "FreeSpace")
	{
		x_par_disable("DriveLetter")
		x_par_enable("folder")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Drive_Information(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["DriveLetter", "folder"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	WhichInformation := ElementParameters.WhichInformation
	if (WhichInformation = "Label" or WhichInformation = "StatusCD" or WhichInformation = "FileSystem" or WhichInformation = "Serial")
	{
		; those informations require a drive letter

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["DriveLetter"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		if (not EvaluatedParameters.DriveLetter)
		{
			x_finish(Environment, "exception", x_lang("Drive is not specified"))
			return
		}

		; copy value to a variable for later use
		path := EvaluatedParameters.DriveLetter
	}
	else if (WhichInformation = "Type" or WhichInformation = "Capacity" or WhichInformation = "FreeSpace")
	{
		; those informations require a folder path

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["folder"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		if not FileExist(EvaluatedParameters.folder)
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Folder"), EvaluatedParameters.folder)) 
			return
		}

		; copy value to a variable for later use
		path := EvaluatedParameters.folder
	}
	
	if (WhichInformation = "FreeSpace")
	{
		; get free space
		DriveSpaceFree, ResultValue, %Path%
	}
	else
	{
		; get specified drive information
		driveget, ResultValue, %WhichInformation%, %Path%
	}

	; check for errors
	if ErrorLevel
	{
		x_finish(Environment, "exception", x_lang("Could not get drive information from '%1%'", Path))
		return
	}
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, ResultValue)

	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Drive_Information(Environment, ElementParameters)
{
	
}





