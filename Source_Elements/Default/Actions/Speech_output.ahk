;Always add this element class name to the global list
x_RegisterElementClass("Action_Speech_output")

;Element type of the element
Element_getElementType_Action_Speech_output()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Speech_output()
{
	return lang("Speech_output")
}

;Category of the element
Element_getCategory_Action_Speech_output()
{
	return lang("Sound") "|" lang("User_Interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Speech_output()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Speech_output()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Speech_output()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Speech_output()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Speech_output(Environment)
{
	tts:=Action_Speech_output_GetSpeechEngines()
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Text_to_speak")})
	parametersToEdit.push({type: "multiLineEdit", id: "text", default: lang("Message"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Wait options")})
	;~ parametersToEdit.push({type: "Checkbox", id: "WaitUntilPreviousFinished", default: 0, label: lang("Wait until previous speech output has finished (if any)")})
	parametersToEdit.push({type: "Checkbox", id: "WaitUntilCurrentFinishes", default: 1, label: lang("Wait until this speech output finishes")})
	parametersToEdit.push({type: "Label", label: lang("Speech engine")})
	parametersToEdit.push({type: "DropDown", id: "TTSEngine", default: tts.default, choices: tts.list, result: "string"})
	parametersToEdit.push({type: "Label", label: lang("Volume")})
	parametersToEdit.push({type: "Slider", id: "volume", default: 100, options: "Range0-100 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 0, options: "Range-10-10 TickInterval1 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Pitch")})
	parametersToEdit.push({type: "Slider", id: "pitch", default: 0, options: "Range-10-10 TickInterval1 tooltip"})

	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Speech_output(Environment, ElementParameters)
{
	return lang("Speech_output") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Speech_output(Environment, ElementParameters)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Speech_output(Environment, ElementParameters)
{
	global ActionSpeech_Output_CurrentExecution
	global ActionSpeech_Output_Queue
	global ActionSpeech_Output_CurrentReadingVoice
	global ActionSpeech_Output_CreatedVoices
	
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	VoiceIdentification:=EvaluatedParameters.TTSEngine EvaluatedParameters.volume EvaluatedParameters.speed EvaluatedParameters.pitch
	;Create voice if not created yet
	if (not ActionSpeech_Output_CreatedVoices[VoiceIdentification])
	{
		ActionSpeech_Output_CreatedVoices[VoiceIdentification] := TTS_CreateVoice(EvaluatedParameters.TTSEngine, EvaluatedParameters.speed, EvaluatedParameters.volume, EvaluatedParameters.pitch)
		if not (ActionSpeech_Output_CreatedVoices[VoiceIdentification])
		{
			x_finish(Environment, "exception", lang("Could not find TTS engine '%1%'", EvaluatedParameters.TTSEngine))
			return
		}
	}
	
	
	;Do the speech output
	try
	{
		ActionSpeech_Output_Queue := Object() ;Delete the queue if any
		if (ActionSpeech_Output_CurrentReadingVoice)
		{
			TTS(ActionSpeech_Output_CreatedVoices[VoiceIdentification], "Stop")
		}
		TTS(ActionSpeech_Output_CreatedVoices[VoiceIdentification], "Speak", EvaluatedParameters.text)
		ActionSpeech_Output_CurrentExecution := x_GetMyUniqueExecutionID(environment)
		ActionSpeech_Output_CurrentReadingVoice := VoiceIdentification
	}
	catch
	{
		x_finish(Environment, "exception", lang("Error on speech output"))
		return
	}
	
	functionObject:= x_NewFunctionObject(environment, "Action_Speech_Output_Task", VoiceIdentification)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	x_SetExecutionValue(Environment, "VoiceIdentification", VoiceIdentification)
	if (EvaluatedParameters.WaitUntilCurrentFinishes)
	{
		x_SetExecutionValue(Environment, "CurrentTask", "WaitUntilCurrentFinishes")
		SetTimer,% functionObject,100
	}
	else
	{
		x_SetExecutionValue(Environment, "CurrentTask", "NotifyWhenCurrentFinishes")
		SetTimer,% functionObject,100
		x_finish(Environment,"normal")
	}
	
	
	return
	
}

ActionSpeech_Output_CreatedVoices:=Object()
ActionSpeech_Output_CurrentExecution:=""
ActionSpeech_Output_CurrentReadingVoice:=""
ActionSpeech_Output_Queue:=Object()

Action_Speech_Output_Task(Environment, VoiceIdentification)
{
	global ActionSpeech_Output_CreatedVoices
	global ActionSpeech_Output_CurrentExecution
	global ActionSpeech_Output_Queue
	
	ExecutionID:=x_GetMyUniqueExecutionID(environment)
	CurrentTask:=x_GetExecutionValue(Environment, "CurrentTask")
	VoiceIdentification:=x_GetExecutionValue(Environment, "VoiceIdentification")
	if (CurrentTask = "NotifyWhenCurrentFinishes")
	{
		if (ActionSpeech_Output_CurrentExecution!=ExecutionID)
		{
			settimer,,off
		}
		else if (TTS(ActionSpeech_Output_CreatedVoices[VoiceIdentification], "GetStatus")!="reading")
		{
			ActionSpeech_Output_CurrentExecution:=""
			settimer,,off
		}
	}
	if (CurrentTask = "WaitUntilCurrentFinishes")
	{
		if (ActionSpeech_Output_CurrentExecution!=ExecutionID or TTS(ActionSpeech_Output_CreatedVoices[VoiceIdentification], "GetStatus")!="reading")
		{
			x_finish(Environment,"normal")
			settimer,,off
		}
	}
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Speech_output(Environment, ElementParameters)
{
	global ActionSpeech_Output_CreatedVoices
	VoiceIdentification:=x_GetExecutionValue(Environment, "VoiceIdentification")
	TTS(ActionSpeech_Output_CreatedVoices[VoiceIdentification], "Stop")
	ActionSpeech_Output_CurrentReadingVoice:=""
	x_finish(Environment,"normal")
}



Action_Speech_output_GetSpeechEngines()
{
	static callResult
	if (IsObject(callResult))
	{
		;only search once
		return callResult
	}
	
	 ;Search for available Engines
	Action_Speech_output_TTSList:=object()

	TTSDefaultLanguage=
	loop,HKEY_LOCAL_MACHINE,SOFTWARE\Microsoft\Speech\Voices\Tokens,1,1 ;Read the registry to find available tts engines
	{
		RegRead, RegistryContent
		;~ fileappend,subkey:%A_LoopRegSubKey%`nregname:%A_LoopRegName%`nregread:%Reginhalt%`n`n,text.txt ;Alle Registry-Einträge dokumentieren. zum Debuggen
		stringgetpos,temp,A_LoopRegName,\,l6 ;It must not conatain a \
		if errorlevel=1 ;if string not found
		if A_LoopRegName=Name
		if RegistryContent
		{
			
			if (Action_Speech_output_TTSRightLanguageFound="") ;If no tts engine of OS language found, check, whether the current tts engine has the OS language
			{
				RegRead, languageKey, %A_LoopRegKey%, %A_LoopRegSubKey%,Language  ;Get the language of the tts engine
				if (languageKey = A_Language) ;Compare with OS language
				{
					Action_Speech_output_TTSDefaultLanguage:=RegistryContent
					Action_Speech_output_TTSRightLanguageFound:=true
				}
				else if Action_Speech_output_TTSDefaultLanguage=
					Action_Speech_output_TTSDefaultLanguage:=RegistryContent
					
			}
			Action_Speech_output_TTSList.push(RegistryContent)
			
		}
	}

	callResult:={list: Action_Speech_output_TTSList, default: Action_Speech_output_TTSDefaultLanguage}
	return callResult
}



