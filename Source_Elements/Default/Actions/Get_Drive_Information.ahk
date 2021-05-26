;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Drive_Information")

;Element type of the element
Element_getElementType_Action_Get_Drive_Information()
{
	return "Action"
}

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

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Drive_Information()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Drive_Information()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
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
	
	listOfdrives:=Object()
	driveget, tempdrives,list
	
	loop,parse,tempdrives
	{
		if a_index=1
			defaultdrive:=A_LoopField ":"
		listOfdrives.push(A_LoopField ":")
		
	}
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "DriveInfo", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Which information")})
	parametersToEdit.push({type: "dropdown", id: "WhichInformation", default: 1, result: "enum", choices: [x_lang("Label"), x_lang("Type"), x_lang("Status"), x_lang("Status of optical disc drive"), x_lang("Capacity"), x_lang("Free disk space"), x_lang("File system"), x_lang("Serial number")], enum: ["Label", "Type", "Status", "StatusCD", "Capacity", "FreeSpace", "FileSystem", "Serial"] })
	
	parametersToEdit.push({type: "Label", label: x_lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultdrive, choices: listOfdrives})
	parametersToEdit.push({type: "Label", label: x_lang("Path")})
	parametersToEdit.push({type: "Folder", id: "folder", label: x_lang("Select a folder")})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Drive_Information(Environment, ElementParameters)
{
	return x_lang("Get_Drive_Information") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Drive_Information(Environment, ElementParameters, staticValues)
{	
	WhichInformation:=ElementParameters.WhichInformation
	if (WhichInformation="Label" or WhichInformation="StatusCD" or WhichInformation="FileSystem" or WhichInformation="Serial")
	{
		x_par_enable("DriveLetter")
		x_par_disable("folder")
	}
	else
	{
		x_par_disable("DriveLetter")
		x_par_enable("folder")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Drive_Information(Environment, ElementParameters)
{
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	if not x_CheckVariableName(Varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("%1% is not valid", x_lang("Ouput variable name '%1%'", varname)))
		return
	}
	
	WhichInformation:=ElementParameters.WhichInformation
	if (WhichInformation="Label" or WhichInformation="StatusCD" or WhichInformation="FileSystem" or WhichInformation="Serial")
	{
		Path := x_replaceVariables(Environment, ElementParameters.DriveLetter) 

		if not Path
		{
			x_finish(Environment,"exception", x_lang("Drive is not specified"))
			return
		}
	}
	else
	{
		Path := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.folder))
		
		if not FileExist(Path)
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.",x_lang("Folder"), Path)) 
			return
		}
	}
	
	if (WhichInformation="FreeSpace")
	{
		DriveSpaceFree, ResultValue,%Path%
	}
	else
	{
		driveget, ResultValue,%WhichInformation%,%Path%
	}
	if ErrorLevel
	{
		x_finish(Environment,"exception", x_lang("Could not be get drive information from '%1%'",Path))
		return
	}
	
	x_SetVariable(Environment,Varname,ResultValue)
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Drive_Information(Environment, ElementParameters)
{
	
}





