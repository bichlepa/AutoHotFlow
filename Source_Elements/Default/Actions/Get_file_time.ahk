﻿;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_File_Time")

;Element type of the element
Element_getElementType_Action_Get_File_Time()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_File_Time()
{
	return lang("Get_File_Time")
}

;Category of the element
Element_getCategory_Action_Get_File_Time()
{
	return lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_File_Time()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_File_Time()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_File_Time()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_File_Time()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_File_Time(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "FileSize", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("Unit")})
	parametersToEdit.push({type: "Radio", id: "TimeType", result: "enum", default: 1, choices: [lang("Modification time"), lang("Creation time"), lang("Last access time")], enum: ["Modification", "Creation", "Access"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_File_Time(Environment, ElementParameters)
{
	return lang("Get_File_Time") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_File_Time(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_File_Time(Environment, ElementParameters)
{
	varname := x_replaceVariables(Environment, ElementParameters.varname)
	if not x_CheckVariableName(varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varname)))
		return
	}

	file := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.file))
	if not FileExist(file)
	{
		x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("File"), file)) 
		return
	}
	
	TimeType:=ElementParameters.Unit
	if (TimeType = "Modification")
		TimeTypePar:="M"
	else if (TimeType = "Creation")
		TimeTypePar :="C"
	else if (TimeType = "Access")
		TimeTypePar :="A"

	FileGetTime,result,% file,% TimeTypePar
	if ErrorLevel
	{
		x_finish(Environment, "exception", lang("Couldn't get file time of file '%1%'",file)) 
		return
	}
	
	x_SetVariable(Environment,Varname,result)
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_File_Time(Environment, ElementParameters)
{
	
}






