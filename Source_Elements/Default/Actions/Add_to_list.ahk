;Always add this element class name to the global list
x_RegisterElementClass("Action_Add_To_List")

;Element type of the element
Element_getElementType_Action_Add_To_List()
{
	return "action"
}

;Name of the element
Element_getName_Action_Add_To_List()
{
	return x_lang("Add_To_List")
}

;Category of the element
Element_getCategory_Action_Add_To_List()
{
	return x_lang("List")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Add_To_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Add_To_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Add_To_List()
{
	return "New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Add_To_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Add_To_List(Environment)
{
	parametersToEdit:=Object()

	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "MyList", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Number of elements")})
	parametersToEdit.push({type: "Radio", id: "NumberOfElements", default: "One", result: "enum", choices: [x_lang("Add one element"), x_lang("Add multiple elements")], enum: ["One", "Multiple"]})

	parametersToEdit.push({type: "Label", label:  x_lang("Content to add")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"], contentID: "Expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "VarValues", content: "String", default: "Element one`nElement two", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: x_lang("Use linefeed as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterComma", default: 0, label: x_lang("Use comma as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: x_lang("Use semicolon as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSpace", default: 0, label: x_lang("Use space as delimiter")})

	parametersToEdit.push({type: "Label", label: x_lang("Key")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: "Last", result: "enum", choices: [x_lang("First integer position"), x_lang("Last integer position"), x_lang("Following position or key")], enum: ["First", "Last", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", id: "InsertMethodLabel", size: "small", label: x_lang("Insertion method if position is an integer and list contains values at this or higher positions")})
	parametersToEdit.push({type: "Radio", id: "InsertMethod", default: "Insert", result: "enum", choices: [x_lang("Insert and increment all other positions"), x_lang("Overwrite value")], enum: ["Insert", "Overwrite"]})	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Add_To_List(Environment, ElementParameters)
{
	if (ElementParameters.WhichPosition = "First")
	{
		PositionText := x_lang("As first value")
	}
	else if (ElementParameters.WhichPosition = "Last")
	{
		PositionText := x_lang("As last value")
	}
	else if (ElementParameters.WhichPosition = "Specified")
	{
		PositionText := x_lang("At position '%1%'", ElementParameters.Position)
	}

	if (ElementParameters.NumberOfElements = "one")
	{
		ValueText := x_lang("Value '%1%'", ElementParameters.VarValue)
	}
	else
	{
		ValueText := x_lang("Multiple values '%1%'", ElementParameters.VarValues)
	}
	
	return % lang("Add to list") " - " ElementParameters.Varname " - " PositionText " - " ValueText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Add_To_List(Environment, ElementParameters, staticValues)
{
	if (ElementParameters.NumberOfElements = "one") ;one element
	{
		x_Par_Enable("VarValue")
	}
	else
	{
		x_Par_Disable("VarValue")
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
	
	x_Par_Enable("Position", (ElementParameters.WhichPosition = "Specified"))
	x_Par_Enable("InsertMethod", (ElementParameters.WhichPosition = "Specified"))
	x_Par_Enable("InsertMethodLabel", (ElementParameters.WhichPosition = "Specified")) ; this will gray out the label (in future versions of AHF)
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Add_To_List(Environment, ElementParameters)
{
	; evaluate parameters
	x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Varname", "NumberOfElements"])
	if (EvaluatedParameters._error)
	{
		return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
	}
	
	; get list from variable
	myList := x_getVariable(Environment, EvaluatedParameters.Varname)
	
	; check whether we got a list
	if (!(IsObject(myList)))
	{
		if (myList = "")
		{
			; we got an empty value. Log a warning and create a new list
			x_log(Environment, x_lang("Warning!") " " x_lang("Variable '%1%' is empty. A new list will be created.", Varname) ,1)
			myList := Object()
		}
		else
		{
			; we got a value wich is not empty and contains something. Finish with exception.
			x_finish(Environment, "exception", x_lang("Variable '%1%' is not empty and does not contain a list.", Varname))
			return
		}
	}
	
	if (ElementParameters.NumberOfElements = "one")
	{
		; one element should be added

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["VarValue", "WhichPosition"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		if (ElementParameters.WhichPosition = "First")
		{
			myList.insertat(1, EvaluatedParameters.VarValue)
		}
		else if (ElementParameters.WhichPosition = "Last")
		{
			myList.push(EvaluatedParameters.VarValue)
		}
		else if (ElementParameters.WhichPosition = "Specified")
		{
			; evaluate more parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Position", "InsertMethod"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			if (EvaluatedParameters.Position = "")
			{
				;position is not set. finish with exception
				return x_finish(Environment, "exception", x_lang("Position is not specified")) 
			}
			
			if (EvaluatedParameters.insertMethod = "Insert")
			{
				; use the insertat function. It will not overwrite if the integer key has a value. If key is not integer, it will work like a direct assignment
				myList.insertat(EvaluatedParameters.Position, EvaluatedParameters.VarValue)
			}
			Else if (EvaluatedParameters.InsertMethod = "Overwrite")
			{
				; assign directly. If the key is an integer, it will overwrite its value. 
				myList[EvaluatedParameters.Position] := EvaluatedParameters.VarValue
			}
		}
	}
	else if (ElementParameters.InitialContent = "multiple") 
	{
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["VarValues", "DelimiterLinefeed", "DelimiterComma", "DelimiterSemicolon", "DelimiterSpace", "WhichPosition"])
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
		parsedList := object()
		loop, parse, % EvaluatedParameters.varvalues, % delimiters
		{
			parsedList.push(A_LoopField)
		}

		if (ElementParameters.WhichPosition = "First")
		{
			; add all elements at first position
			for oneIndex, oneValue in parsedList
			{
				myList.insertat(1, oneValue)
			}
		}
		else if (ElementParameters.WhichPosition = "Last")
		{
			; push all elements to last position
			for oneIndex, oneValue in parsedList
			{
				myList.push(oneValue)
			}
		}
		else if (ElementParameters.WhichPosition = "Specified")
		{
			; evaluate more parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Position", "InsertMethod"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			; copy position value
			position := EvaluatedParameters.Position

			; check whether position is an integer
			if position is not integer
			{
				; it is not possible to insert multiple values to a single key. Raise exception.
				return x_finish(Environment, "exception", x_lang("Position '%1%' is not an integer value", position))
			}

			if (EvaluatedParameters.InsertMethod = "Insert")
			{
				; use the insertat function. It will not overwrite the values.
				for oneIndex, oneValue in parsedList
				{
					myList.insertat(position + a_index - 1, oneValue)
				}
			}
			else if (EvaluatedParameters.InsertMethod = "Overwrite")
			{
				; assign directly. It will overwrite existing values. 
				for oneIndex, oneValue in parsedList
				{
					myList[position + a_index - 1] := oneValue
				}
			}
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
Element_stop_Action_Add_To_List(Environment, ElementParameters)
{
	
}