;Always add this element class name to the global list
AllElementClasses.push("Condition_Expression")

Element_getPackage_Condition_Expression()
{
	return "default"
}

Element_getElementType_Condition_Expression()
{
	return "condition"
}

Element_getName_Condition_Expression()
{
	return lang("Expression")
}

Element_getCategory_Condition_Expression()
{
	return lang("Variable")
}

Element_getParameters_Condition_Expression()
{
	return ["expression"]
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
		
	if (x_EvaluateExpression(Environment,ElementParameters.Expression))
		return x_finish(Environment,"yes")
	else
		return x_finish(Environment,"no")
	

}