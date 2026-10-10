
;Name of the element
Element_getName_Action_Substring2()
{
	return x_lang("Substring2")
}

;Category of the element
Element_getCategory_Action_Substring2()
{
	return x_lang("Text")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Substring2()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Substring2()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Substring2()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Substring2(Environment)
{
	parametersToEdit:=Object()
	
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Start position")})
	parametersToEdit.push({type: "Radio", id: "WhereToBegin", default: "FromLeft", choices: [x_lang("Start from left"), x_lang("Start from following position"), x_lang("Search for a string and start there")], result: "enum", enum: ["FromLeft", "Position", "String"]})
	parametersToEdit.push({type: "Label", label: x_lang("Start position"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "StartPos", default: 1, content: "positiveInteger", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Text (excluding and including)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["StartTextExcluding", "StartTextIncluding"], default: 1, content: ["String", "Expression"], contentID: "expressionStart", contentDefault: "string"})
	parametersToEdit.push({type: "Checkbox", id: "StartTextCaseSensitive", default: 0, label: x_lang("Case sensitive")})

	parametersToEdit.push({type: "Label", label: x_lang("End position")})
	parametersToEdit.push({type: "Radio", id: "WhereToEnd", default: "CountOfChars", choices: [x_lang("End at the end of the string"), x_lang("End after a count of characters"), x_lang("End at following position"), x_lang("Search for a string and end there")], result: "enum", enum: ["AtTheEnd", "CountOfChars", "Position", "String"]})
	parametersToEdit.push({type: "Label", label: x_lang("Count of characters"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "Length", default: 5, content: "positiveIntegerOrZero", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("End position"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "EndPos", default: 5, content: "positiveInteger", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Text (including and excluding)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["EndTextIncluding", "EndTextExcluding"], default: 1, content: ["String", "Expression"], contentID: "expressionEnd", contentDefault: "String"})
	parametersToEdit.push({type: "Checkbox", id: "EndTextCaseSensitive", default: 0, label: x_lang("Case sensitive")})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Substring2(Environment, ElementParameters)
{
	return x_lang("Substring") "2 - " ElementParameters.Varname " - " ElementParameters.VarValue
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Substring2(Environment, ElementParameters, staticValues)
{	if (ElementParameters.WhereToBegin = "Position")
	{
		x_Par_Enable("StartPos")

		x_Par_Disable("StartTextExcluding")
		x_Par_Disable("StartTextIncluding")
		x_Par_Disable("StartTextCaseSensitive")
	}
	else if (ElementParameters.WhereToBegin = "String")
	{
		x_Par_Enable("StartPos")
		x_Par_Enable("UntilTheEnd")
		
		x_Par_Enable("StartTextExcluding")
		x_Par_Enable("StartTextIncluding")
		x_Par_Enable("StartTextCaseSensitive")
	}
	else if (ElementParameters.WhereToBegin = "FromLeft")
	{
		x_Par_Disable("StartPos")
		x_Par_Disable("StartTextExcluding")
		x_Par_Disable("StartTextIncluding")
		x_Par_Disable("StartTextCaseSensitive")
	}

	if (ElementParameters.WhereToEnd = "AtTheEnd")
	{
		x_Par_Disable("Length")
		x_Par_Disable("EndPos")
		x_Par_Disable("EndTextIncluding")
		x_Par_Disable("EndTextExcluding")
		x_Par_Disable("EndTextCaseSensitive")

	}
	else if (ElementParameters.WhereToEnd = "CountOfChars")
	{
		x_Par_Enable("Length")
		x_Par_Disable("EndPos")
		x_Par_Disable("EndTextIncluding")
		x_Par_Disable("EndTextExcluding")
		x_Par_Disable("EndTextCaseSensitive")
	}
	else if (ElementParameters.WhereToEnd = "Position")
	{
		x_Par_Disable("Length")
		x_Par_Enable("EndPos")
		x_Par_Disable("EndTextIncluding")
		x_Par_Disable("EndTextExcluding")
		x_Par_Disable("EndTextCaseSensitive")
	}
	else if (ElementParameters.WhereToEnd = "String")
	{
		x_Par_Disable("Length")
		x_Par_Disable("EndPos")
		x_Par_Enable("EndTextIncluding")
		x_Par_Enable("EndTextExcluding")
		x_Par_Enable("EndTextCaseSensitive")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Substring2(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["StartPos", "StartTextExcluding", "StartTextIncluding", "Length", "EndPos", "EndTextIncluding", "EndTextExcluding"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	startPos := ""
	endPos := ""
	haystack := EvaluatedParameters.VarValue
	everythingValid := true
	
	; get start position
	switch (EvaluatedParameters.WhereToBegin)
	{
		case "FromLeft":
			startPos := 1
		
		case "Position":

			; Begin from specified position
			
			; evaluate additional parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["StartPos"])
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}

			startPos := EvaluatedParameters.StartPos
			
		case "String":
		
			; evaluate additional parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["StartPos", "StartTextExcluding", "StartTextIncluding"])
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}

			if (EvaluatedParameters.StartTextExcluding EvaluatedParameters.StartTextIncluding = "")
			{
				x_finish(Environment, "exception", "Start text not specified")
				return
			}
			
			; search for the string
			startPos := instr(haystack, EvaluatedParameters.StartTextExcluding EvaluatedParameters.StartTextIncluding, EvaluatedParameters.StartTextCaseSensitive, EvaluatedParameters.startPos)
			if (startPos)
			{
				; string was found. save the prefix and add the string length to position
				startPos += strlen(EvaluatedParameters.StartTextExcluding)
			}
			Else
			{
				; the start string was not found. We won't throw an error. But be won't search for the string.
				everythingValid := false
			}
	}
	
	if (everythingValid)
	{
		; get end position
		switch (EvaluatedParameters.WhereToEnd)
		{
			case "AtTheEnd":
				length := ""
			
			case "CountOfChars":
				; evaluate additional parameters
				x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Length"])
				if (EvaluatedParameters._error)
				{
					x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
					return
				}
				length := EvaluatedParameters.length
				

			case "Position":
				; evaluate additional parameters
				x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["EndPos"])
				if (EvaluatedParameters._error)
				{
					x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
					return
				}
				length := EvaluatedParameters.EndPos - EvaluatedParameters.StartPos + 1

				if (length < 0)
				{
					x_finish(Environment, "exception", "End position is higher than start position")
					return
				}

			case "String":
			
				; evaluate additional parameters
				x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["EndTextIncluding", "EndTextExcluding"])
				if (EvaluatedParameters._error)
				{
					x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
					return
				}
				
				if (EvaluatedParameters.EndTextIncluding EvaluatedParameters.EndTextExcluding = "")
				{
					x_finish(Environment, "exception", "End text not specified")
					return
				}

				endPos := instr(haystack, EvaluatedParameters.EndTextIncluding EvaluatedParameters.EndTextExcluding, EvaluatedParameters.EndTextCaseSensitive, startPos)
				if (endPos)
				{
					; string was found. save the postfix and calculate the length
					endPos += strlen(EvaluatedParameters.EndTextIncluding)
					length := endPos - startPos
				}
				Else
				{
					; the end string was not found. We won't throw an error. But be won't search for the string.
					everythingValid := false
				}
		}
	}
	
	if (everythingValid)
	{
		; get the substring
		if (length != "")
			result := SubStr(haystack, startPos, length)
		Else
			result := SubStr(haystack, startPos)
	}
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, result)
	x_SetVariable(Environment, "a_startPos", startPos, "thread")
	x_SetVariable(Environment, "a_length", length, "thread")

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Substring2(Environment, ElementParameters)
{
}



