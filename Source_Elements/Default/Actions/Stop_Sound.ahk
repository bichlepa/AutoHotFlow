﻿
;Name of the element
Element_getName_Action_Stop_Sound()
{
	return x_lang("Stop_Sound")
}

;Category of the element
Element_getCategory_Action_Stop_Sound()
{
	return x_lang("Sound")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Stop_Sound()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Stop_Sound()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Stop_Sound()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Stop_Sound(Environment)
{
	parametersToEdit:=Object()
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Stop_Sound(Environment, ElementParameters)
{
	return x_lang("Stop_Sound") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Stop_Sound(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Stop_Sound(Environment, ElementParameters)
{
	; stop sound
	SoundPlay, -

	; finish
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Stop_Sound(Environment, ElementParameters)
{
}






