;Always add this element class name to the global list
AllElementClasses.push("Trigger_Manual")

Element_getPackage_Trigger_Manual()
{
	return "default"
}

Element_getElementType_Trigger_Manual()
{
	return "trigger"
}

Element_getName_Trigger_Manual()
{
	return lang("Manual")
}

Element_getCategory_Trigger_Manual()
{
	return lang("User_interaction")
}

Element_getParameters_Trigger_Manual()
{
	return ["ID"]
}

Element_getParametrizationDetails_Trigger_Manual()
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("ID")})
	parametersToEdit.push({type: "Edit", id: "ID", content: "String",  default: "Trigger " x_randomPhrase()})
	return parametersToEdit
}

Element_enable_Trigger_Manual(Environment, ElementParameters)
{
	global
	x_enabled(Environment, "normal", "The manual trigger can now be triggered by other flows.")

}

Element_disable_Trigger_Manual(Environment, ElementParameters)
{
	x_disabled(Environment, "normal", "The manual trigger cannot anymore be triggered by other flows.")

}

Element_trigger_Trigger_Manual(Environment, ElementParameters)
{
	x_trigger(Environment)
}


Element_GenerateName_Trigger_Manual(Environment, ElementParameters)
{
	global
	return % lang("Manual") "`n" ElementParameters.id 
}

Element_CheckSettings_Trigger_Manual(Environment, ElementParameters)
{
	;~ ElementSettings.enable(ElementParameters.BlockKey,"WhenRelease")
}