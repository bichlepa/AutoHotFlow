;Always add this element class name to the global list
AllElementClasses.push("Action_New_variable")

Element_getPackage_Action_New_variable()
{
	return "default"
}

Element_getElementType_Action_New_variable()
{
	return "action"
}

Element_getName_Action_New_variable()
{
	return lang("New_variable")
}

Element_getIconPath_Action_New_variable()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_New_variable()
{
	return lang("Variable")
}

Element_getParameters_Action_New_variable()
{
	return ["Varname", "expression", "VarValue"]
}

Element_getParametrizationDetails_Action_New_variable()
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Value")})
	parametersToEdit.push({type: "Edit", id: ["VarValue","expression"], default: ["New element",1], content: "StringOrExpression", WarnIfEmpty: true})

	return parametersToEdit
}

Element_run_Action_New_variable(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	Value := ""
	
	if not x_CheckVariableName(varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varname)))
		return
	}
	
	if (ElementParameters.Expression = 2)
		Value := x_EvaluateExpression(Environment, ElementParameters.VarValue)
	else
		Value := x_replaceVariables(Environment, ElementParameters.VarValue)
	
	x_SetVariable(Environment, Varname, Value)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}

Element_GenerateName_Action_New_variable(Environment, ElementParameters)
{
	global
	return % lang("New_variable") " - " ElementParameters.Varname " = " ElementParameters.VarValue
	
}