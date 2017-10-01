;Always add this element class name to the global list
AllElementClasses.push("Action_Delete_From_Ini")

;Element type of the element
Element_getElementType_Action_Delete_From_Ini()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Delete_From_Ini()
{
	return lang("Delete_From_Ini")
}

;Category of the element
Element_getCategory_Action_Delete_From_Ini()
{
	return lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Delete_From_Ini()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Delete_From_Ini()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Delete_From_Ini()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Delete_From_Ini()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Delete_From_Ini()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "file"})
	parametersToEdit.push({id: "Action"})
	parametersToEdit.push({id: "Section"})
	parametersToEdit.push({id: "Key"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Delete_From_Ini(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Path of an .ini file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "Action", result: "enum", default: 1, choices: [lang("Delete a key"), lang("Delete a section")], enum: ["DeleteKey", "DeleteSection"]})
	parametersToEdit.push({type: "Label", label: lang("Section")})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Delete_From_Ini(Environment, ElementParameters)
{
	return lang("Delete_From_Ini") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Delete_From_Ini(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Delete_From_Ini(Environment, ElementParameters)
{

	Action := ElementParameters.Action

	Section := x_replaceVariables(Environment,ElementParameters.Section)

	file := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))

	if (not Section)
	{
		x_finish(Environment,"exception",lang("Section not specified") )
		return
	}
	
	if (Action = "DeleteKey")
	{
		Key := x_replaceVariables(Environment,ElementParameters.Key)
		if (not Key)
		{
			x_finish(Environment,"exception",lang("Key not specified") )
			return
		}
		
		IniDelete,% file,% Section,% Key
		if errorlevel
		{
			x_finish(Environment,"exception",lang("Error on delete from ini") )
			return
		}
	
	}
	else if (Action = "DeleteSection")
	{
		IniDelete,% file,% Section
		if errorlevel
		{
			x_finish(Environment,"exception",lang("Error on delete from ini") )
			return
		}
	}
	
	x_finish(Environment,"normal")
	return
	

	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Delete_From_Ini(Environment, ElementParameters)
{
	
}


