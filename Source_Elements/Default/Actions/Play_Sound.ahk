;Always add this element class name to the global list
x_RegisterElementClass("Action_Play_Sound")

;Element type of the element
Element_getElementType_Action_Play_Sound()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Play_Sound()
{
	return x_lang("Play_Sound")
}

;Category of the element
Element_getCategory_Action_Play_Sound()
{
	return x_lang("Sound")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Play_Sound()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Play_Sound()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Play_Sound()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Play_Sound()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Play_Sound(Environment)
{
	parametersToEdit:=Object()
	
	listOfSysSounds:=Object()
	loop, %a_windir%\media\*
	{
		listOfSysSounds.push(a_loopfilename)
	}
	
	parametersToEdit.push({type: "Label", label: x_lang("Select sound")})
	parametersToEdit.push({type: "Radio", id: "WhichSound", default: 1, choices: [x_lang("System sound"), x_lang("Sound file")], result: "enum", enum: ["SystemSound", "SoundFile"]})
	parametersToEdit.push({type: "dropdown", id: "systemSound", default: "tada.wav", choices: listOfSysSounds, result: "string"})
	parametersToEdit.push({type: "File", id: "soundfile", label: x_lang("Select a sound file"), options: 1})
	parametersToEdit.push({type: "Label", label: x_lang("Preview")})
	parametersToEdit.push({type: "button", id: "stopSoundNow",  goto: "Action_Play_Sound_StopSoundNow", label: x_lang("Stop playback now")})
	
	parametersToEdit.updateOnEdit:=True
	return parametersToEdit
}

Action_Play_Sound_StopSoundNow()
{
	SoundPlay,stoooooooop
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Play_Sound(Environment, ElementParameters)
{
	return x_lang("Play_Sound") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Play_Sound(Environment, ElementParameters, staticValues)
{	
	static playedSound
	
	if (ElementParameters.WhichSound = "SoundFile")
	{
		x_Par_Disable("systemSound")
		x_Par_Enable("soundfile")
	}
	else
	{
		x_Par_Enable("systemSound")
		x_Par_Disable("soundfile")
		
		if (playedSound!=ElementParameters.systemSound)
		{
			playedSound:=ElementParameters.systemSound
			if (not x_FirstCallOfCheckSettings(Environment))
			{
				if playedSound
				{
					SoundPlay,%a_windir%\media\%playedSound%
				}
			}
		}
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Play_Sound(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (ElementParameters.WhichSound = "SystemSound")
	{
		if (EvaluatedParameters.systemSound) ;Maybe unnecessary
		{
			SoundPlay,% a_windir "\media\" EvaluatedParameters.systemSound
		}
	}
	else
	{
		SoundPlay,% EvaluatedParameters.soundfile
	}
	if errorlevel
	{
		x_finish(Environment,"exception", x_lang("Sound could not be played"))
		return
	}
	
	x_finish(Environment,"normal")
	return
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Play_Sound(Environment, ElementParameters)
{
}






