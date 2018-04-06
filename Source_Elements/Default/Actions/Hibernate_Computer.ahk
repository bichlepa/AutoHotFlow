;Always add this element class name to the global list
x_RegisterElementClass("Action_Hibernate_Computer")

;Element type of the element
Element_getElementType_Action_Hibernate_Computer()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Hibernate_Computer()
{
	return lang("Hibernate_Computer")
}

;Category of the element
Element_getCategory_Action_Hibernate_Computer()
{
	return lang("Power")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Hibernate_Computer()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Hibernate_Computer()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Hibernate_Computer()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Hibernate_Computer()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Hibernate_Computer()
{
	parametersToEdit:=Object()
	
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Hibernate_Computer(Environment)
{
	parametersToEdit:=Object()
	
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Hibernate_Computer(Environment, ElementParameters)
{
	return lang("Hibernate_Computer") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Hibernate_Computer(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Hibernate_Computer(Environment, ElementParameters)
{


	DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0) ;Hibernate
	x_finish(Environment,"normal")
	return
	

	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Hibernate_Computer(Environment, ElementParameters)
{
	
}






