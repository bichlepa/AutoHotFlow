﻿;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Start_up")

;Element type of the element
Element_getElementType_Trigger_Start_up()
{
	return "Trigger"
}

;Name of the element
Element_getName_Trigger_Start_up()
{
	return x_lang("Start_up")
}

;Category of the element
Element_getCategory_Trigger_Start_up()
{
	return x_lang("Power")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Start_up()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Start_up()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Start_up()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Start_up()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Start_up(Environment)
{
	parametersToEdit := Object()
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Start_up(Environment, ElementParameters)
{
	return x_lang("Start_up") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Start_up(Environment, ElementParameters, staticValues)
{	
	
}



;Called when the trigger is activated
Element_enable_Trigger_Start_up(Environment, ElementParameters)
{
	; enable the trigger
	x_enabled(Environment, "normal")

	; if we have windows startup, trigger right now
	if (x_isWindowsStartup())
		x_trigger(Environment)
		
	; return true, if trigger was enabled
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Start_up(Environment, ElementParameters, TriggerData)
{

}

;Called when the trigger should be disabled.
Element_disable_Trigger_Start_up(Environment, ElementParameters)
{
	x_disabled(Environment, "normal")
}



