;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_From_List")

;Element type of the element
Element_getElementType_Action_Get_From_List()
{
	return "action"
}

;Name of the element
Element_getName_Action_Get_From_List()
{
	return x_lang("Get_From_List")
}

;Category of the element
Element_getCategory_Action_Get_From_List()
{
	return x_lang("List")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_From_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_From_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_From_List()
{
	return "Source_elements\default\icons\New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_From_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_From_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Key or position")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: 1, result: "enum", choices: [x_lang("First integer position"), x_lang("Last integer position"), x_lang("Random integer position"), x_lang("Following position or key")], enum: ["First", "Last", "Random", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_From_List(Environment, ElementParameters)
{
	PositionText := " - "
	if (ElementParameters.WhichPosition = "First")
	{
		PositionText .= x_lang("First value")
	}
	else if (ElementParameters.WhichPosition = "Last")
	{
		PositionText .= x_lang("Last value")
	}
	else if (ElementParameters.WhichPosition = "Random")
	{
		PositionText .= x_lang("Random value")
	}
	else if (ElementParameters.WhichPosition = "Specified")
	{
		PositionText .= x_lang("At position '%1%'", ElementParameters.Position)
	}
	return lang("Get from list %1%", ElementParameters.ListName) PositionText " - " ElementParameters.Varname
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_From_List(Environment, ElementParameters, staticValues)
{
	if (ElementParameters.WhichPosition = "Specified")
	{
		x_Par_Enable("Position")
	}
	Else
	{
		x_Par_Disable("Position")
	}
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_From_List(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["Position"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get list
	myList := EvaluatedParameters.ListName
	
	; check whether we got a list
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.", ElementParameters.ListName)) 
		return
	}
	
	if (EvaluatedParameters.WhichPosition = "First")
	{
		; get element from first position
		Position := myList.MinIndex()
		if (Position = "")
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.", ElementParameters.ListName)) 
			return
		}
	}
	else if (EvaluatedParameters.WhichPosition = "Last")
	{
		; get element from last position
		Position := myList.MaxIndex()
		if (Position = "")
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.", ElementParameters.ListName)) 
			return
		}
	}
	else if (EvaluatedParameters.WhichPosition = "Random")
	{
		; get element from random position

		; get min and max position
		MinPosition := myList.MinIndex()
		MaxPosition := myList.MaxIndex()
		if (MinPosition = "")
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.", ElementParameters.ListName)) 
			return
		}
		
		; generate a random number
		random, Position, %minindex%, %maxindex%
	}
	else if (ElementParameters.WhichPosition = "Specified")
	{
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Position"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		Position := EvaluatedParameters.position

		; check whether positoin is specified
		if (Position = "")
		{
			x_finish(Environment, "exception", x_lang("%1% is not secified.", x_lang("Position")))
			return
		}
		; check whether list contains the key
		if (not myList.HasKey(Position))
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain the key '%2%'.", ElementParameters.ListName, Position))
			return
		}
	}
	
	; write value from list to variable
	x_SetVariable(Environment, Varname, myList[Position])
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_From_List(Environment, ElementParameters)
{
	
}
