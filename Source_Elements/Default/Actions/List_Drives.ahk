;Always add this element class name to the global list
x_RegisterElementClass("Action_List_drives")

;Element type of the element
Element_getElementType_Action_List_drives()
{
	return "Action"
}

;Name of the element
Element_getName_Action_List_drives()
{
	return x_lang("List_drives")
}

;Category of the element
Element_getCategory_Action_List_drives()
{
	return x_lang("Drive")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_List_drives()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_List_drives()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_List_drives()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_List_drives()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_List_drives(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "DriveList", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Drive type")})
	parametersToEdit.push({type: "Radio", id: "WhetherDriveTypeFilter", default: "all", choices: [x_lang("Find all drives"), x_lang("Get only a Specified type of drive")], result: "enum", enum: ["all", "filter"]})
	parametersToEdit.push({type: "DropDown", id: "DriveType", default: "CDROM", choices: [x_lang("Disk drives"), x_lang("Removable drives"), x_lang("Fixed drives"), x_lang("Network drives"), x_lang("RAM disk drives"), x_lang("Unknown drives")], result: "enum", enum: ["CDROM", "REMOVABLE", "FIXED", "NETWORK", "RAMDISK", "UNKNOWN"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("If no drive can be found")})
	parametersToEdit.push({type: "Radio", id: "IfNothingFound", default: "Exception", choices: [x_lang("Normal") " - " x_lang("Make output variable empty"),x_lang("Throw exception")], result: "enum", enum: ["Normal", "Exception"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_List_drives(Environment, ElementParameters)
{
	return x_lang("List_drives") " - " ElementParameters.Varname
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_List_drives(Environment, ElementParameters, staticValues)
{	
	x_Par_Enable("DriveType", ElementParameters.WhetherDriveTypeFilter = "filter")
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_List_drives(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check whether a filter should be used
	if (EvaluatedParameters.WhetherDriveTypeFilter = "filter")
	{
		DriveType := EvaluatedParameters.DriveType
	}
	
	; list drives
	driveget, foundDrives, list, % DriveType

	; check for error
	if ErrorLevel
	{
		; there was an error. Return according to settings
		if (EvaluatedParameters.IfNothingFound = "exception")
		{
			x_finish(Environment, "exception", x_lang("No drives found"))
			return
		}
		Else
		{
			x_finish(Environment, "normal", x_lang("No drives found"))
			return
		}
	}
	
	; convert result to a list
	foundDrivesObject := Object()
	loop, parse, foundDrives
	{
		foundDrivesObject.push(A_LoopField)
		
	}

	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, foundDrivesObject)
	
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_List_drives(Environment, ElementParameters)
{
}






