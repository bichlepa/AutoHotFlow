;Always add this element class name to the global list
x_RegisterElementClass("Condition_Expression")

Element_getPackage_Condition_Expression()
{
	return "default"
}

Element_getElementType_Condition_Expression()
{
	return "condition"
}

Element_getElementLevel_Condition_Expression()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Condition_Expression()
{
	return lang("Expression")
}

Element_getCategory_Condition_Expression()
{
	return lang("Variable")
}

Element_getParametrizationDetails_Condition_Expression(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Expression")})
	parametersToEdit.push({type: "Edit", id: "Expression", content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

Element_GenerateName_Condition_Expression(Environment, ElementParameters)
{
	global
	return % lang("Expression") " - " ElementParameters.expression
	
}

Element_run_Condition_Expression(Environment, ElementParameters)
{
	evRes:=x_EvaluateExpression(Environment,ElementParameters.Expression)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Expression) "`n`n" evRes.error) 
		return
	}
	else
	{
		if (evRes.result)
			return x_finish(Environment,"yes")
		else
			return x_finish(Environment,"no")
	}
	

}