;Always add this element class name to the global list
x_RegisterElementClass("Action_New_variable")

Element_getPackage_Action_New_variable()
{
	return "default"
}

Element_getElementType_Action_New_variable()
{
	return "action"
}

Element_getElementLevel_Action_New_variable()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
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

Element_getParametrizationDetails_Action_New_variable(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Value")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})

	return parametersToEdit
}

Element_GenerateName_Action_New_variable(Environment, ElementParameters)
{
	global
	return % lang("New_variable") " - " ElementParameters.Varname " = " ElementParameters.VarValue
	
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
	
	if (ElementParameters.Expression = "expression")
	{
		evRes := x_EvaluateExpression(Environment, ElementParameters.VarValue)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.VarValue) "`n`n" evRes.error) 
			return
		}
		else
		{
			Value:=evRes.result
		}
	}
	else
		Value := x_replaceVariables(Environment, ElementParameters.VarValue)
	
	x_SetVariable(Environment, Varname, Value)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}