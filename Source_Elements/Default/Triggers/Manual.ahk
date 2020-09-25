﻿;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Manual")

Element_getPackage_Trigger_Manual()
{
	return "default"
}

Element_getElementType_Trigger_Manual()
{
	return "trigger"
}

Element_getElementLevel_Trigger_Manual()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Trigger_Manual()
{
	return lang("Manual")
}

Element_getCategory_Trigger_Manual()
{
	return lang("User_interaction")
}

Element_getParametrizationDetails_Trigger_Manual(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("ID")})
	parametersToEdit.push({type: "Edit", id: "ID", content: "String",  default: "Trigger " x_randomPhrase()})
	return parametersToEdit
}

Element_GenerateName_Trigger_Manual(Environment, ElementParameters)
{
	global
	return % lang("Manual") "`n""" ElementParameters.id   """"
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


