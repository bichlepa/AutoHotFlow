
;Name of the element
Element_getName_Loop_Condition()
{
	return x_lang("Condition")
}

;Category of the element
Element_getCategory_Loop_Condition()
{
	return x_lang("Variable")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Loop_Condition()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
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
	
	parametersToEdit.push({type: "Label", label: x_lang("Condition")})
	parametersToEdit.push({type: "Edit", id: "Expression", default: "a_index <= 5", content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "EvaluateOnFirstIteration", default: 1, label: x_lang("Evaluate on first iteration")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_Condition(Environment, ElementParameters)
{
	return x_lang("Condition") " - " ElementParameters.Expression
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Loop_Condition(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Loop_Condition(Environment, ElementParameters)
{
	; get entry point and decide what to do
	entryPoint := x_getEntryPoint(environment)
	if (entryPoint = "Head") ;Initialize loop
	{
		; check whether we need to evaluate the expression on first iteration 
		if (ElementParameters.EvaluateOnFirstIteration)
		{
			; we need to evaluate the expression on first iteration. Do it now.
			evalutedExpression := x_EvaluateExpression(Environment,ElementParameters.Expression)
			if (evalutedExpression.error)
			{
				x_finish(Environment, "exception", evalutedExpression.error) 
				return
			}
		}
		Else
		{
			; we don't need to evalute the expression on first iteration.
			; Write true as expression result
			evalutedExpression.result := true
		}
		
		; check expression result
		if (evalutedExpression.result)
		{
			; we either don't need to evaluate the expression or the expression is not false 
			; start first iteration
			; set a_index as loop variable
			x_SetVariable(Environment, "A_Index", 1, "loop")
			x_finish(Environment, "head")
		}
		else
		{
			; the expression is false
			; End without a single iteration
			x_finish(Environment, "tail") ;Leave the loop
		}
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		; get current index and increase it
		index := x_GetVariable(Environment, "A_Index")
		index++
		x_SetVariable(Environment, "A_Index", index, "loop")
		
		; evaluate expression parameter
		evalutedExpression := x_EvaluateExpression(Environment,ElementParameters.Expression)
		if (evalutedExpression.error)
		{
			x_finish(Environment, "exception", evalutedExpression.error) 
			return
		}
		
		; check expression result
		if (evalutedExpression.result)
		{
			; the expression is not false
			; Start next iteration
			x_finish(Environment, "head") ;Continue with next iteration
		}
		else
		{
			; the expression is false
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
		x_finish(Environment, "exception", x_lang("No information whether the connection leads to head or tail"))
	}
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_Condition(Environment, ElementParameters)
{
}
