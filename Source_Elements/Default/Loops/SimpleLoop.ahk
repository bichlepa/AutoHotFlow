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
	return lang("Simple loop")
}

;Category of the element
Element_getCategory_Loop_SimpleLoop()
{
	return lang("General")
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
	parametersToEdit.push({type: "Label", label: lang("Repeats")})
	parametersToEdit.push({type: "Checkbox", id: "Infinite", default: 0, label: lang("Endless loop")})
	parametersToEdit.push({type: "Edit", id: "repeatCount", default: 5, content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_SimpleLoop(Environment, ElementParameters)
{
	global
	
	if (ElementParameters.Infinite)
		return lang("Simple loop") ": " lang("Infinite loop") 
	else
		return lang("Simple loop") ": " ElementParameters.repeatCount " " lang("Repeats") 
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
	entryPoint := x_getEntryPoint(environment)
	
	if (not ElementParameters.Infinite)
	{
		evRes := x_EvaluateExpression(Environment, ElementParameters.repeatCount)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.repeatCount) "`n`n" evRes.error) 
			return
		}
		else
		{
			repeatCount:=evRes.result
		}
	}
	
	if (entryPoint = "Head") ;Initialize loop
	{
		if (ElementParameters.Infinite or repeatCount >= 1)
		{
			x_SetVariable(Environment, "A_Index", 1, "loop")
			x_finish(Environment, "head")
		}
		else
		{
			x_finish(Environment, "tail")
		}
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		index := x_GetVariable(Environment, "A_Index")
		index++
		if (ElementParameters.Infinite or repeatCount >= index)
		{
			x_SetVariable(Environment, "A_Index", index, "loop")
			x_finish(Environment, "head")
		}
		else
		{
			x_finish(Environment, "tail")
		}
		
	}
	else if (entryPoint = "Break") ;Break loop
	{
		x_finish(Environment, "tail")
		
	}
	else
	{
		x_finish(Environment, "exception", lang("No information whether the connection lead into head or tail"))
	}


}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_SimpleLoop(Environment, ElementParameters)
{
}
