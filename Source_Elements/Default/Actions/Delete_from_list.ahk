;Always add this element class name to the global list
x_RegisterElementClass("Action_Delete_From_List")

;Element type of the element
Element_getElementType_Action_Delete_From_List()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Delete_From_List()
{
	return x_lang("Delete_From_List")
}

;Category of the element
Element_getCategory_Action_Delete_From_List()
{
	return x_lang("List")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Delete_From_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Delete_From_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Delete_From_List()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Delete_From_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Delete_From_List(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "myList", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Which element")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", result: "enum", default: "Last", choices: [x_lang("First integer position"), x_lang("Last integer position"), x_lang("Following position or key")], enum: ["First", "Last", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", id: "DeleteMethodLabel", size: "small", label: x_lang("Deletion method if position is an integer and list contains values at this or higher positions")})
	parametersToEdit.push({type: "Radio", id: "DeleteMethod", default: "Decrement", result: "enum", choices: [x_lang("Delete and decrement all higher positions"), x_lang("Delete and keep the gap")], enum: ["Decrement", "KeepGap"]})	
	
	parametersToEdit.push({type: "Label", label: x_lang("Deleted value")})
	parametersToEdit.push({type: "Checkbox", id: "WriteToVariable", default: 0, label: x_lang("Write deleted value to variable")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "RemovedValue", content: "VariableName", WarnIfEmpty: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Delete_From_List(Environment, ElementParameters)
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
	else if (ElementParameters.WhichPosition = "Specified")
	{
		PositionText .= x_lang("At position '%1%'", ElementParameters.Position)
	}

	WriteToVariableText := ""
	if (ElementParameters.WriteToVariable)
	{
		WriteToVariableText .= " - " x_lang("Write deleted value to '%1%'", ElementParameters.Varname)
	}
	return lang("Delete from list %1%", ElementParameters.ListName) PositionText " - " ElementParameters.Varname WriteToVariableText
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Delete_From_List(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.WhichPosition = "Specified")
	{
		x_Par_Enable("Position")
	}
	Else
	{
		x_Par_Disable("Position")
	}
	if (ElementParameters.WhichPosition = "First" or ElementParameters.WhichPosition = "Specified")
	{
		x_Par_Enable("DeleteMethodLabel")
		x_Par_Enable("DeleteMethod")
	}
	Else
	{
		x_Par_Disable("DeleteMethodLabel")
		x_Par_Disable("DeleteMethod")
	}
	if (ElementParameters.WriteToVariable)
	{
		x_Par_Enable("Varname")
	}
	Else
	{
		x_Par_Disable("Varname")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Delete_From_List(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["Position", "Varname"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; get list from variable
	myList := x_getVariable(Environment, EvaluatedParameters.ListName)
	
	; check whether we got a list
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.", EvaluatedParameters.ListName)) 
		return
	}

	if (EvaluatedParameters.WhichPosition = "First")
	{
		; remove element from first position
		Position := myList.MinIndex()
		if (Position = "")
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.", EvaluatedParameters.ListName)) 
			return
		}
	}
	else if (EvaluatedParameters.WhichPosition = "Last")
	{
		; remove element from last position
		Position := myList.MaxIndex()
		if (Position = "")
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.", EvaluatedParameters.ListName)) 
			return
		}
	}
	else if (EvaluatedParameters.WhichPosition = "Specified")
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
			x_finish(Environment, "exception", x_lang("%1% is not specified.", x_lang("Position")))
			return
		}
		; check whether list contains the key
		if (not myList.HasKey(Position))
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain the key '%2%'.", EvaluatedParameters.ListName, Position))
			return
		}
	}

	if (EvaluatedParameters.DeleteMethod = "Decrement")
	{
		; we will call the removeAt function
		deletedValue := myList.RemoveAt(Position)
	}
	else if (EvaluatedParameters.DeleteMethod = "KeepGap")
	{
		; we will call de delete function
		deletedValue := myList.Delete(Position)
	}

	if (ElementParameters.WriteToVariable)
	{
		; we will write deleted value to a variable
		
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Varname"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}

		; write deleted value to variable
		x_SetVariable(Environment, EvaluatedParameters.Varname, deletedValue)
	}
	
	; write changed list to variable
	x_SetVariable(Environment, EvaluatedParameters.ListName, myList)
	

	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Delete_From_List(Environment, ElementParameters)
{
	
}






