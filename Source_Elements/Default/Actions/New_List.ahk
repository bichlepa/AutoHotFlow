;Always add this element class name to the global list
x_RegisterElementClass("Action_New_List")

;Element type of the element
Element_getElementType_Action_New_List()
{
	return "action"
}

;Name of the element
Element_getName_Action_New_List()
{
	return x_lang("New_List")
}

;Category of the element
Element_getCategory_Action_New_List()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_New_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_New_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_New_List()
{
	return "Source_elements\default\icons\New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_New_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_New_List(Environment)
{
	parametersToEdit:=Object()

	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "myList", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Number of elements")})
	parametersToEdit.push({type: "Radio", id: "NumberOfElements", default: "None", result: "enum", choices: [x_lang("Empty list"), x_lang("Initialize with one element"), x_lang("Initialize with multiple elements")], enum: ["None", "One", "Multiple"]})

	parametersToEdit.push({type: "Label", label:  x_lang("Initial content")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "VarValues", content: "String", default: "Element one`nElement two", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: x_lang("Use linefeed as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterComma", default: 0, label: x_lang("Use comma as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: x_lang("Use semicolon as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSpace", default: 0, label: x_lang("Use space as delimiter")})

	parametersToEdit.push({type: "Label", label: x_lang("Key")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: "First", result: "enum", choices: [x_lang("Numerically as first element"), x_lang("Following key")], enum: ["First", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_New_List(Environment, ElementParameters)
{
	if (ElementParameters.NumberOfElements != "None")
	{
		PositionText := " - "
		if (ElementParameters.WhichPosition = "First")
		{
			PositionText .= x_lang("As first value")
		}
		else if (ElementParameters.WhichPosition = "Specified")
		{
			PositionText .= x_lang("At position '%1%'", ElementParameters.Position)
		}
	}

	if (ElementParameters.NumberOfElements = "None")
	{
		ValueText := x_lang("Empty")
	}
	else if (ElementParameters.NumberOfElements = "one")
	{
		ValueText := x_lang("Value '%1%'", ElementParameters.VarValue)
	}
	else
	{
		ValueText := x_lang("Multiple values '%1%'", ElementParameters.VarValues)
	}
	
	return % lang("New list %1%", ElementParameters.Varname) PositionText " - " ValueText
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_New_List(Environment, ElementParameters, staticValues)
{
	if (ElementParameters.NumberOfElements = "one") ;one element
	{
		x_Par_Enable("VarValue")
		x_Par_Enable("WhichPosition")
		x_Par_Enable("Position", (ElementParameters.WhichPosition = "Specified"))
	}
	else
	{
		x_Par_Disable("VarValue")
		x_Par_Disable("WhichPosition")
		x_Par_Disable("Position")
	}
	
	if (ElementParameters.NumberOfElements = "multiple") ;Multiple elements
	{
		x_Par_Enable("VarValues")
		x_Par_Enable("DelimiterLinefeed")
		x_Par_Enable("DelimiterComma")
		x_Par_Enable("DelimiterSemicolon")
		x_Par_Enable("DelimiterSpace")
	}
	else
	{
		x_Par_Disable("VarValues")
		x_Par_Disable("DelimiterLinefeed")
		x_Par_Disable("DelimiterComma")
		x_Par_Disable("DelimiterSemicolon")
		x_Par_Disable("DelimiterSpace")
	}
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_New_List(Environment, ElementParameters)
{
	; evaluate parameters
	x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Varname", "NumberOfElements"])
	if (EvaluatedParameters._error)
	{
		return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
	}
	
	; create a new object which will be the output variable
	myList := Object()
	
	; check option NumberOfElements
	if (ElementParameters.NumberOfElements = "None")
	{
		; list should be empty
	}
	else if (ElementParameters.NumberOfElements = "one")
	{
		; list should contain one element

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["VarValue", "WhichPosition"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		if (ElementParameters.WhichPosition = "First")
		{
			myList.push(EvaluatedParameters.VarValue)
		}
		else if (ElementParameters.WhichPosition = "Specified")
		{
			; evaluate more parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Position"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			if (EvaluatedParameters.Position = "")
			{
				;position is not set. finish with exception
				return x_finish(Environment, "exception", x_lang("Position is not specified")) 
			}
			
			; write the value at the position
			myList[EvaluatedParameters.Position] := EvaluatedParameters.VarValue
		}
	}
	else if (ElementParameters.NumberOfElements = "multiple") 
	{
		; list should contain multiple elements

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["VarValues", "DelimiterLinefeed", "DelimiterComma", "DelimiterSemicolon", "DelimiterSpace"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		; prepare delimiter list
		delimiters := ""
		if (ElementParameters.DelimiterLinefeed)
			delimiters .= "`n"
		if (ElementParameters.DelimiterComma)
			delimiters .= ","
		if (ElementParameters.DelimiterSemicolon)
			delimiters .= ";"
		if (ElementParameters.DelimiterSpace)
			delimiters .= " "
		
		; parse string and add all elements to list
		loop, parse, % EvaluatedParameters.varvalues, % delimiters
		{
			myList.push(A_LoopField)
		}
	}
	
	; write object to variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, myList)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_New_List(Environment, ElementParameters)
{
	
}

