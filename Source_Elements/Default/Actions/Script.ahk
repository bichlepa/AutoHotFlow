;Always add this element class name to the global list
x_RegisterElementClass("Action_Script")

Element_getPackage_Action_Script()
{
	return "default"
}

Element_getElementType_Action_Script()
{
	return "action"
}

Element_getElementLevel_Action_Script()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Script()
{
	return lang("Script")
}

Element_getIconPath_Action_Script()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Script()
{
	return lang("Variable")
}

Element_getParameters_Action_Script()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Script"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Action_Script(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "label", label: lang("Script")})
	parametersToEdit.push({type: "multilineEdit", id: "Script", default: "", WarnIfEmpty: true})

	return parametersToEdit
}

Element_GenerateName_Action_Script(Environment, ElementParameters)
{
	global
	return % lang("Script") " - " ElementParameters.Script 
	
}

Element_run_Action_Script(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Script := ElementParameters.Script
	
	x_EvaluateScript(Environment, Script)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}