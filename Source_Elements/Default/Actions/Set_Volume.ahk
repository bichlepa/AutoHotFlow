;Always add this element class name to the global list
x_RegisterElementClass("Action_Set_Volume")

;Element type of the element
Element_getElementType_Action_Set_Volume()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Set_Volume()
{
	return x_lang("Set_Volume")
}

;Category of the element
Element_getCategory_Action_Set_Volume()
{
	return x_lang("Sound")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Set_Volume()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Set_Volume()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Set_Volume()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Set_Volume()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Set_Volume(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Action")})
	parametersToEdit.push({type: "Radio", id: "Action", default: 1, choices: [x_lang("Set mute state"), x_lang("Set a specific volume"), x_lang("Increase or decrease volume")], result: "enum", enum: ["Mute", "Absolute", "Relative"]})
	parametersToEdit.push({type: "Label", label: x_lang("Mute settings")})
	parametersToEdit.push({type: "Radio", id: "Mute", default: 1, choices: [x_lang("Mute on"), x_lang("Mute off"), x_lang("Toggle")], retult: "enum", enum: ["On", "Off", "Toggle"]})
	parametersToEdit.push({type: "Label", label: x_lang("Absolute volume")})
	parametersToEdit.push({type: "Slider", id: "volume", default: 80, options: "Range0-100 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: x_lang("Relative volume")})
	parametersToEdit.push({type: "Slider", id: "volumeRelative", default: 10, options: "Range-100-100 TickInterval10 tooltip"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Set_Volume(Environment, ElementParameters)
{
	return x_lang("Set_Volume") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Set_Volume(Environment, ElementParameters, staticValues)
{	
	
	if (ElementParameters.Action = "Absolute")
	{
		x_Par_Disable("Mute")
		x_Par_Enable("volume")
		x_Par_Disable("volumeRelative")
	}
	else if (ElementParameters.Action = "Relative")
	{
		x_Par_Disable("Mute")
		x_Par_Disable("volume")
		x_Par_Enable("volumeRelative")
	}
	else if (ElementParameters.Action = "Mute")
	{
		
		x_Par_Enable("Mute")
		x_Par_Disable("volume")
		x_Par_Disable("volumeRelative")
	}
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Set_Volume(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.Action="Relative")
	{
		if (ElementParameters.volumeRelative<0)
			SoundSet,% ElementParameters.volumeRelative
		else
			SoundSet,% "+" ElementParameters.volumeRelative
	}
	else if (EvaluatedParameters.Action="Absolute")
	{
		SoundSet,% ElementParameters.Volume
	}
	else if (EvaluatedParameters.Action="Mute")
	{
		if (EvaluatedParameters.Mute="On")
			SoundSet,1,,mute
		else if (EvaluatedParameters.Mute="Off")
			SoundSet,0,,mute
		else if (EvaluatedParameters.Mute="Toggle")
			SoundSet,+1,,mute
	}
	
	
	x_finish(Environment,"normal")
	return
	
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Set_Volume(Environment, ElementParameters)
{
}






