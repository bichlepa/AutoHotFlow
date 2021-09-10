;Always add this element class name to the global list
x_RegisterElementClass("Loop_Work_through_a_list")

;Element type of the element
Element_getElementType_Loop_Work_through_a_list()
{
	return "loop"
}

;Name of the element
Element_getName_Loop_Work_through_a_list()
{
	return x_lang("Work_through_a_list")
}

;Category of the element
Element_getCategory_Loop_Work_through_a_list()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Loop_Work_through_a_list()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Loop_Work_through_a_list()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Loop_Work_through_a_list()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Loop_Work_through_a_list()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Loop_Work_through_a_list(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "List", content: "VariableName", WarnIfEmpty: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_Work_through_a_list(Environment, ElementParameters)
{
	global
	return x_lang("Work_through_a_list") ": " ElementParameters.VarValue 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Loop_Work_through_a_list(Environment, ElementParameters, staticValues)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Loop_Work_through_a_list(Environment, ElementParameters)
{
	; get entry point and decide what to do
	entryPoint := x_getEntryPoint(environment)
	if (entryPoint = "Head") ;Initialize loop
	{
		; evaluate parameters
		EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		; get variable content
		varContentList := x_GetVariable(Environment, EvaluatedParameters.VarValue)
		
		; check whether variable content is an object
		if not isobject(varContentList)
		{
			x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.", EvaluatedParameters.VarValue))
			return
		}
		
		; make a copy of the list
		CurrentList := []
		for tempkey, tempvalue in varContentList
		{
			CurrentList.push({key: tempkey, value: tempvalue})
		}

		; check whether CurrentList has values
		if (CurrentList.haskey(1))
		{
			; start first iteration
			; write the array to a hidden variable. We will use it on next iteration to get the next value.
			x_SetVariable(Environment, "A_LoopCurrentList", CurrentList, "loop", true)
			
			; set a_index as loop variable
			x_SetVariable(Environment, "A_Index", 1, "loop")
			
			; set a_index as loop variable
			x_SetVariable(Environment, "A_LoopKey", CurrentList[1].key, "loop")
			x_SetVariable(Environment, "A_LoopField", CurrentList[1].value, "loop")
			
			x_finish(Environment, "head")
		}
		else
		{
			; the CurrentList array is empty. End without a single iteration
			x_finish(Environment, "tail") ;Leave the loop
		}
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		; get current index and increase it
		index := x_GetVariable(Environment, "A_Index")
		index++
		; get array with the parsed elements
		CurrentList := x_GetVariable(Environment, "A_LoopCurrentList", true)
		
		if (CurrentList.haskey(index))
		{
			; there is another element in the array
			; Start next iteration
			x_SetVariable(Environment, "A_Index", index, "loop")
			x_SetVariable(Environment, "A_LoopKey", CurrentList[index].key, "loop")
			x_SetVariable(Environment, "A_LoopField", CurrentList[index].value, "loop")
			x_finish(Environment, "head") ;Continue with next iteration
		}
		else
		{
			; we reached the end of the list.
			x_finish(Environment, "tail") ;Leave the loop
		}
	}
	else if (entryPoint = "Break") ;Break loop
	{
		x_finish(Environment, "tail")
		
	}
	else
	{
		x_finish(Environment, "exception", x_lang("No information whether the connection lead into head or tail"))
	}
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_Work_through_a_list(Environment, ElementParameters)
{
}