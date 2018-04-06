;Always add this element class name to the global list
x_RegisterElementClass("Loop_SimpleLoop")

Element_getPackage_Loop_SimpleLoop()
{
	return "default"
}

Element_getElementType_Loop_SimpleLoop()
{
	return "loop"
}

Element_getElementLevel_Loop_SimpleLoop()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Loop_SimpleLoop()
{
	return lang("Simple loop")
}

Element_getCategory_Loop_SimpleLoop()
{
	return lang("General")
}

Element_getParameters_Loop_SimpleLoop()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Infinite"})
	parametersToEdit.push({id: "repeatCount"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Loop_SimpleLoop(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Repeats")})
	parametersToEdit.push({type: "Checkbox", id: "Infinite", default: 0, label: lang("Endless loop")})
	parametersToEdit.push({type: "Edit", id: "repeatCount", default: 5, content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}


Element_GenerateName_Loop_SimpleLoop(Environment, ElementParameters)
{
	global
	
	if (ElementParameters.Infinite)
		return lang("Simple loop") ": " lang("Infinite loop") 
	else
		return lang("Simple loop") ": " ElementParameters.repeatCount " " lang("Repeats") 
}

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