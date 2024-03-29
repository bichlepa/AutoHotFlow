﻿
;Name of the element
Element_getName_Condition_File_Has_Attribute()
{
	return x_lang("File_Has_Attribute")
}

;Category of the element
Element_getCategory_Condition_File_Has_Attribute()
{
	return x_lang("File")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_File_Has_Attribute()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Condition_File_Has_Attribute()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_File_Has_Attribute()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_File_Has_Attribute(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file")})

	parametersToEdit.push({type: "Label", label: x_lang("Which attribute")})
	parametersToEdit.push({type: "Radio", id: "Attribute", default: 1, choices: [x_lang("Normal"), x_lang("Read only"), x_lang("Archive"), x_lang("System"), x_lang("Hidden"), x_lang("Directory"), x_lang("Offline"), x_lang("Compressed"), x_lang("Temporary")], result: "enum", enum: ["N", "R", "A", "S", "H", "D", "O", "C", "T"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_File_Has_Attribute(Environment, ElementParameters)
{
	switch (ElementParameters.Attribute)
	{
		case "N":
		attributeText := x_lang("Normal")
		case "R":
		attributeText := x_lang("Read only")
		case "A":
		attributeText := x_lang("Archive")
		case "S":
		attributeText := x_lang("System")
		case "H":
		attributeText := x_lang("Hidden")
		case "D":
		attributeText := x_lang("Directory")
		case "O":
		attributeText := x_lang("Offline")
		case "C":
		attributeText := x_lang("Compressed")
		case "T":
		attributeText := x_lang("Temporary")
	}
	return x_lang("File_Has_Attribute") " - " attributeText " - " ElementParameters.file
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_File_Has_Attribute(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_File_Has_Attribute(Environment, ElementParameters)
{
	;evalute the parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get file attribute
	FileGetAttrib, result, % EvaluatedParameters.file
	if ErrorLevel
	{
		; an error occured. Check whether file exists
		if not fileexist(tempPath)
		{
			; file does not exist. finish with exception
			x_finish(Environment, "exception", x_lang("File '%1%' does not exist", EvaluatedParameters.file)) 
			return
		}
		else
		{
			; file exists. Reason is unknown. Finish with exception
			x_finish(Environment, "exception", x_lang("Attributes of file '%1%' could not be read", EvaluatedParameters.file)) 
			return
		}
	}
	
	; check whether the attribute exists
	IfInString, result, % EvaluatedParameters.Attribute
		x_finish(Environment, "yes")
	else
		x_finish(Environment, "no")
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_File_Has_Attribute(Environment, ElementParameters)
{
}






