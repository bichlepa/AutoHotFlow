;Always add this element class name to the global list
x_RegisterElementClass("Action_Shuffle_list")

;Element type of the element
Element_getElementType_Action_Shuffle_list()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Shuffle_list()
{
	return x_lang("Shuffle_list")
}

;Category of the element
Element_getCategory_Action_Shuffle_list()
{
	return x_lang("List")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Shuffle_list()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Shuffle_list()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Shuffle_list()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Shuffle_list()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Shuffle_list(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output list name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "shuffledList", content: "VariableName", WarnIfEmpty: true})

	parametersToEdit.push({type: "Label", label: x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "myList", content: "Expression", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Shuffle_list(Environment, ElementParameters)
{
	return x_lang("Shuffle_list") " - " ElementParameters.Varname " - " ElementParameters.VarValue
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Shuffle_list(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Shuffle_list(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get list from variable
	myList := EvaluatedParameters.VarValue
	
	; check whether we got a list
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.", ElementParameters.VarValue)) 
		return
	}
	
	; The input list may contain some non-numerical entries.
	; So we will remove and copy the numerial values to temporary objects and then re-insert them into the original list in random order.

	; prepare temporary lists
	valueList := Object()
	keyList := Object()

	;Copy all numeric elements to a separate list
	for oneKey, oneValue in myList
	{
		if oneKey is number
		{
			valueList.insert(oneValue)
			keyList.insert(oneKey)
		}
	}
	;Delete all numeric elements from original list
	for oneIndex, oneKey in keyList
	{
		myList.delete(oneKey)
	}

	;Add all previous copied values to the list in random order
	countOfElements := valueList.maxIndex()
	loop % countOfElements
	{
		; generate random index
		random, randomnumber, 1, % countOfElements + 1 - A_Index
		; get and remove value from temporary list
		oneValue := valueList.RemoveAt(randomnumber)
		; push value to original list
		myList.push(oneValue)
	}

	; write list to variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, myList)
	
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Shuffle_list(Environment, ElementParameters)
{
}






