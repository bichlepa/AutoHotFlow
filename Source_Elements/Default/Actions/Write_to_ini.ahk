;Always add this element class name to the global list
AllElementClasses.push("Action_Write_to_ini")

;Element type of the element
Element_getElementType_Action_Write_to_ini()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Write_to_ini()
{
	return lang("Write_to_ini")
}

;Category of the element
Element_getCategory_Action_Write_to_ini()
{
	return lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Write_to_ini()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Write_to_ini()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Write_to_ini()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Write_to_ini()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Write_to_ini(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Value")})
	parametersToEdit.push({type: "Edit", id: "Value", default: "value", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "Label", label: lang("Section")})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Write_to_ini(Environment, ElementParameters)
{
	return lang("Write_to_ini") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Write_to_ini(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Write_to_ini(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	file:=x_GetFullPath(Environment,EvaluatedParameters.file)
	
	IniWrite,% EvaluatedParameters.Value,% file,% EvaluatedParameters.section,% EvaluatedParameters.key
	
	if ErrorLevel
	{
		x_finish(Environment, "exception", lang("Could not write value '%1%' to ini file '%2%', section '%3%', key '%4%'",EvaluatedParameters.Value,file,EvaluatedParameters.section,EvaluatedParameters.key)) 
		return
		
	}

	x_finish(Environment,"normal")
	return
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Write_to_ini(Environment, ElementParameters)
{
}






