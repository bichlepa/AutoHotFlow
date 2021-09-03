;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Manual")

;Element type of the element
Element_getElementType_Trigger_Manual()
{
	return "trigger"
}

;Name of the element
Element_getName_Trigger_Manual()
{
	return x_lang("Manual")
}

;Category of the element
Element_getCategory_Trigger_Manual()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Manual()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Manual()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Manual()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Manual()
{
	;"Stable" or "Experimental"
	return "Stable"
}


;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Manual(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("ID")})
	parametersToEdit.push({type: "Edit", id: "ID", content: "rawstring",  default: "Trigger " x_randomPhrase()})
	
	; request that the result of this function is never cached (because we want a unique random phrase for each element)
	parametersToEdit.updateOnEdit := true
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Manual(Environment, ElementParameters)
{
	return % x_lang("Manual") "`n""" ElementParameters.id   """"
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Manual(Environment, ElementParameters, staticValues)
{	

}


;Called when the trigger is activated
Element_enable_Trigger_Manual(Environment, ElementParameters)
{
	x_enabled(Environment, "normal")

	; return true, if trigger was enabled
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Manual(Environment, ElementParameters, TriggerData)
{
	; Write the manual trigger ID into the variable.
	x_SetVariable(Environment, "A_ManualTriggerID", ElementParameters.id, "thread")
}

;Called when the trigger should be disabled.
Element_disable_Trigger_Manual(Environment, ElementParameters)
{
	x_disabled(Environment, "normal")

}


