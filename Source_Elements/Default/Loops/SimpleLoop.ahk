;Always add this element class name to the global list
x_RegisterElementClass("Loop_SimpleLoop")

;Element type of the element
Element_getElementType_Loop_SimpleLoop()
{
	return "loop"
}

;Name of the element
Element_getName_Loop_SimpleLoop()
{
	return x_lang("Simple loop")
}

;Category of the element
Element_getCategory_Loop_SimpleLoop()
{
	return x_lang("General")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Loop_SimpleLoop()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Loop_SimpleLoop()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Loop_SimpleLoop()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Loop_SimpleLoop()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Loop_SimpleLoop(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Repeats")})
	parametersToEdit.push({type: "Checkbox", id: "Infinite", default: 0, label: x_lang("Endless loop")})
	parametersToEdit.push({type: "Edit", id: "repeatCount", default: 5, content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_SimpleLoop(Environment, ElementParameters)
{
	global
	
	if (ElementParameters.Infinite)
		return x_lang("Simple loop") ": " x_lang("Infinite loop") 
	else
		return x_lang("Simple loop") ": " ElementParameters.repeatCount " " x_lang("Repeats") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Loop_SimpleLoop(Environment, ElementParameters)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Loop_SimpleLoop(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; get entry point and decide what to do
	entryPoint := x_getEntryPoint(environment)
	if (entryPoint = "Head") ;Initialize loop
	{
		; check condition
		if (EvaluatedParameters.Infinite or EvaluatedParameters.repeatCount >= 1)
		{
			; loop is either infinite is repeat count greater than 0.
			; start first iteration
			; set a_index as loop variable
			x_SetVariable(Environment, "A_Index", 1, "loop")
			x_finish(Environment, "head")
		}
		else
		{
			; loop is neither infinite nor is repeat count greater than 0.
			; end without a single iteration
			x_finish(Environment, "tail")
		}
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		; get current index and increase it
		index := x_GetVariable(Environment, "A_Index")
		index++

		; check condition
		if (EvaluatedParameters.Infinite or EvaluatedParameters.repeatCount >= index)
		{
			; loop is either infinite is repeat count greater than index.
			; start next iteration
			x_SetVariable(Environment, "A_Index", index, "loop")
			x_finish(Environment, "head")
		}
		else
		{
			; last iteration reached.
			x_finish(Environment, "tail")
		}
		
	}
	else if (entryPoint = "Break") ;Break loop
	{
		; break the loop
		x_finish(Environment, "tail")
		
	}
	else
	{
		;This should never happen, but I suggest to keep this code for catching bugs in AHF.
		x_finish(Environment, "exception", x_lang("No information whether the connection lead into head or tail"))
	}
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_SimpleLoop(Environment, ElementParameters)
{
}
