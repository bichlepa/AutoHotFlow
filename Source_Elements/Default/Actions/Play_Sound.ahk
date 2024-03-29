﻿
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

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Play_Sound()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
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
	
	; get a list of all system sound
	listOfSysSounds := Object()
	loop, %a_windir%\media\*
	{
		listOfSysSounds.push(a_loopfilename)
	}
	
	parametersToEdit.push({type: "Label", label: x_lang("Select sound")})
	parametersToEdit.push({type: "Radio", id: "WhichSound", default: "SystemSound", choices: [x_lang("System sound"), x_lang("Sound file")], result: "enum", enum: ["SystemSound", "SoundFile"]})
	parametersToEdit.push({type: "dropdown", id: "systemSound", default: "tada.wav", choices: listOfSysSounds, result: "string"})
	parametersToEdit.push({type: "File", id: "soundfile", label: x_lang("Select a sound file"), options: 1})

	parametersToEdit.push({type: "Label", label: x_lang("Preview #noun")})
	parametersToEdit.push({type: "button", id: "startSoundNow",  goto: "Action_Play_Sound_StartSoundNow", label: x_lang("Start playback")})
	parametersToEdit.push({type: "button", id: "stopSoundNow",  goto: "Action_Play_Sound_StopSoundNow", label: x_lang("Stop playback now")})
	
	; request that the result of this function is never cached (because of the system sound list)
	parametersToEdit.updateOnEdit:=True
	return parametersToEdit
}

Action_Play_Sound_StartSoundNow()
{
	whichSound := x_Par_GetValue("WhichSound")
	if (whichSound = "SystemSound")
	{
		systemSound := x_Par_GetValue("systemSound")
		SoundPlay, %a_windir%\media\%systemSound%
	}
	Else
	{
		soundfile := x_Par_GetValue("soundfile")
		SoundPlay, %soundfile%
	}
}
Action_Play_Sound_StopSoundNow()
{
	; stop soundplay
	SoundPlay, stoooooooop
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Play_Sound(Environment, ElementParameters)
{
	switch (ElementParameters.WhichSound)
	{
		case "SystemSound":
		soundString := ElementParameters.systemSound
		case "SoundFile":
		soundString := ElementParameters.soundfile
	}
	return x_lang("Play_Sound") " - " soundString
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
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Play_Sound(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["soundfile"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (EvaluatedParameters.WhichSound = "SystemSound")
	{
		; play a system sound
		SoundPlay, % a_windir "\media\" EvaluatedParameters.systemSound
	}
	else
	{
		; a sound file should be played

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["soundfile"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}

		; play sound file
		SoundPlay, % EvaluatedParameters.soundfile
	}

	; check for errors
	if errorlevel
	{
		x_finish(Environment, "exception", x_lang("Sound could not be played"))
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






