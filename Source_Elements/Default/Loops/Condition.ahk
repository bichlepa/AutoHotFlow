;Always add this element class name to the global list
x_RegisterElementClass("Loop_Condition")

;Element type of the element
Element_getElementType_Loop_Condition()
{
	return "Loop"
}

;Name of the element
Element_getName_Loop_Condition()
{
	return lang("Condition")
}

;Category of the element
Element_getCategory_Loop_Condition()
{
	return lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Loop_Condition()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Loop_Condition()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Loop_Condition()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Loop_Condition()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Loop_Condition(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Condition")})
	parametersToEdit.push({type: "Edit", id: "Expression", default: "a_index <= 5", content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "EvaluateOnFirstIteration", default: 1, label: lang("Evaluate on first iteration")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_Condition(Environment, ElementParameters)
{
	return lang("Condition") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Loop_Condition(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Loop_Condition(Environment, ElementParameters)
{
	entryPoint := x_getEntryPoint(environment)
	
	if (entryPoint = "Head") ;Initialize loop
	{
		EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, "Expression")
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		if (EvaluatedParameters.EvaluateOnFirstIteration = 0 || x_EvaluateExpression(Environment,ElementParameters.Expression))
		{
			x_SetVariable(Environment, "A_Index", 1, "loop")
			x_finish(Environment, "head")
		}
		else
		{
			x_finish(Environment, "tail") ;Leave the loop
		}
		

	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		index := x_GetVariable(Environment, "A_Index")
		index++
		
		if (x_EvaluateExpression(Environment,ElementParameters.Expression))
		{
			x_SetVariable(Environment, "A_Index", index, "loop")
			x_finish(Environment, "head") ;Continue with next iteration
		}
		else
		{
			x_finish(Environment, "tail") ;Leave the loop
		}
		
	}
	else if (entryPoint = "Break") ;Break loop
	{
		x_finish(Environment, "tail") ;Leave the loop
		
	}
	else
	{
		;This should never happen, but I suggest to keep this code for catching bugs in AHF.
		x_finish(Environment, "exception", lang("No information whether the connection leads into head or tail"))
	}
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_Condition(Environment, ElementParameters)
{
}






