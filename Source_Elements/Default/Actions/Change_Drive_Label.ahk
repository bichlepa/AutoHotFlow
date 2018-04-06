;Always add this element class name to the global list
x_RegisterElementClass("Action_Change_Drive_Label")

;Element type of the element
Element_getElementType_Action_Change_Drive_Label()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Change_Drive_Label()
{
	return lang("Change_Drive_Label")
}

;Category of the element
Element_getCategory_Action_Change_Drive_Label()
{
	return lang("Drive")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Change_Drive_Label()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Change_Drive_Label()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Change_Drive_Label()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Change_Drive_Label()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Change_Drive_Label()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "DriveLetter"})
	parametersToEdit.push({id: "NewLabel"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Change_Drive_Label(Environment)
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
	
	parametersToEdit.push({type: "Label", label: lang("Drive letter")})
	parametersToEdit.push({type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultdrive, choices: listOfdrives})
	parametersToEdit.push({type: "Label", label: lang("New label")})
	parametersToEdit.push({type: "Edit", id: "NewLabel", content: "String"})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Change_Drive_Label(Environment, ElementParameters)
{
	return lang("Change_Drive_Label") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Change_Drive_Label(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Change_Drive_Label(Environment, ElementParameters)
{
	NewLabel := x_replaceVariables(Environment,ElementParameters.NewLabel)
	DriveLetter := x_replaceVariables(Environment, ElementParameters.DriveLetter) 

	if not DriveLetter
	{
		x_finish(Environment,"exception", lang("Drive is not specified"))
		return
	}
	
	;Admin rights are needed
	drive,label,%DriveLetter%,%NewLabel%
	
	if ErrorLevel
	{
		x_finish(Environment,"exception", lang("Label %1% could not be set to drive %2%",NewLabel,DriveLetter))
		return
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Change_Drive_Label(Environment, ElementParameters)
{
	
}





