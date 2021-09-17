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
	return x_lang("Speech_output")
}

;Category of the element
Element_getCategory_Action_Speech_output()
{
	return x_lang("Sound") "|" x_lang("User_Interaction")
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

;Icon file name which will be shown in the background of the element
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
	; get all available voices
	tts := Action_Speech_output_GetSpeechEngines()

	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Text_to_speak")})
	parametersToEdit.push({type: "multiLineEdit", id: "text", default: x_lang("Message"), content: "String"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Wait options")})
	parametersToEdit.push({type: "Checkbox", id: "WaitUntilPreviousFinished", default: 0, label: x_lang("Wait until previous speech output has finished (if any)")})
	parametersToEdit.push({type: "Checkbox", id: "WaitUntilCurrentFinishes", default: 1, label: x_lang("Wait until this speech output finishes")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Speech engine")})
	parametersToEdit.push({type: "DropDown", id: "TTSEngine", default: tts.default, choices: tts.list, result: "string"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Volume #sound volume")})
	parametersToEdit.push({type: "Slider", id: "volume", default: 100, options: "Range0-100 TickInterval10 tooltip"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 0, options: "Range-10-10 TickInterval1 tooltip"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Pitch #tone pitch")})
	parametersToEdit.push({type: "Slider", id: "pitch", default: 0, options: "Range-10-10 TickInterval1 tooltip"})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Speech_output(Environment, ElementParameters)
{
	return x_lang("Speech_output") " - " ElementParameters.multiLineEdit " - " ElementParameters.TTSEngine
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Speech_output(Environment, ElementParameters, staticValues)
{	
	
}

; prepare global variables.
; TODO: this implementation is not very good. It may break the compatibility later when we will have multiple execution threads. We need more API functions.
; If you are implementing a new element. Please do not copy any code from here!
ActionSpeech_Output_Queue := []
ActionSpeech_Output_Stop := False
ActionSpeech_Output_CurrentExecution := ""
settimer, Action_Speech_Output_Task, 100

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Speech_output(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	

	; create a callback function
	functionObject := x_NewFunctionObject(environment, "Action_Speech_Output_Callback")
	
	uniqueID := x_GetMyUniqueExecutionID(environment)
	stopOthers := not EvaluatedParameters.WaitUntilPreviousFinished
	wait := EvaluatedParameters.WaitUntilCurrentFinishes

	; add speech output data to queue
	Action_Speech_Output_AddToQueue(EvaluatedParameters.text, EvaluatedParameters.TTSEngine, EvaluatedParameters.Volume, EvaluatedParameters.Speed, EvaluatedParameters.Pitch, uniqueID, stopOthers, wait, functionObject)

	return
}



;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Speech_output(Environment, ElementParameters)
{
	uniqueID := x_GetMyUniqueExecutionID(environment)
	Action_Speech_Output_Stop(uniqueID)
}

Action_Speech_Output_Callback(environment, result, message = "")
{
	x_finish(environment, result, message)
}


; returns a list of all available TTS engines
Action_Speech_output_GetSpeechEngines()
{
	static callResult
	if (IsObject(callResult))
	{
		;only search once
		return callResult
	}
	
	 ;Search for available Engines
	TTSList := object()

	TTSDefaultLanguage := ""
	;Read the registry to find available tts engines
	loop, HKEY_LOCAL_MACHINE, SOFTWARE\Microsoft\Speech\Voices\Tokens, 1, 1
	{
		; read content of registry entry
		RegRead, RegistryContent

		stringgetpos, temp, A_LoopRegName, \, l6 ;It must not conatain a \

		if errorlevel = 1 ;if string not found
		if (A_LoopRegName = "Name")
		if RegistryContent
		{
			if (not RightLanguageFound) ;If no tts engine of OS language found, check, whether the current tts engine has the OS language
			{
				RegRead, languageKey, %A_LoopRegKey%, %A_LoopRegSubKey%,Language  ;Get the language of the tts engine

				;Compare with OS language and try to find default language
				if (languageKey = A_Language) 
				{
					DefaultLanguage := RegistryContent
					RightLanguageFound := true
				}
				else if not DefaultLanguage
				{
					DefaultLanguage := RegistryContent
				}
					
			}
			TTSList.push(RegistryContent)
		}
	}

	callResult := {list: TTSList, default: DefaultLanguage}
	return callResult
}

; stops the speech output of an element
Action_Speech_Output_Stop(uniqueID)
{
	global ActionSpeech_Output_CurrentExecution
	global ActionSpeech_Output_Stop
	global ActionSpeech_Output_Queue
	
	; check whether speech output of this element is running
	if (ActionSpeech_Output_CurrentExecution = uniqueID)
	{
		; speech output of this element is running. stop it
		ActionSpeech_Output_Stop := true
	}
	Else
	{
		; speech output of this element is not running.

		; check whether there is a queue entry for this element
		for oneIndex, oneQueueEntry in ActionSpeech_Output_Queue
		{
			if (oneQueueEntry.uniqueID = uniqueID)
			{
				; queue entry found. delete it
				ActionSpeech_Output_Queue.RemoveAt(oneIndex)

				; call the callback function
				callback := oneQueueEntry.callback
				%callback%("normal", x_lang("Speech output cancelled"))

				break
			}
		}
	}
}

; add a speech output command to queue
Action_Speech_Output_AddToQueue(TextToSpeak, TTSEngine, Volume, Speed, Pitch, uniqueID, StopAllOthers, wait, callback)
{
	global ActionSpeech_Output_Queue
	global ActionSpeech_Output_Stop

	; prepare entry
	QueueEntry := {TextToSpeak: TextToSpeak, TTSEngine: TTSEngine, Volume: Volume, Speed: Speed, Pitch: Pitch, uniqueID: uniqueID, wait: wait, callback: callback}

	; check whether we need to stop other speech outputs
	if (StopAllOthers)
	{
		; make copy of old list
		oldList := ActionSpeech_Output_Queue

		; delete queue and add only this entry
		ActionSpeech_Output_Queue := [QueueEntry]
		; stop speech output
		ActionSpeech_Output_Stop := true

		; call the callback function of each queue element
		for oneIndex, oneQueueEntry in oldList
		{
			; call the callback function
			callback := oneQueueEntry.callback
			%callback%("normal", x_lang("Speech output cancelled"))
		}
	}
	Else
	{
		; add the command to queue
		ActionSpeech_Output_Queue.push(QueueEntry)
	}
}

; task which performs the speech output
Action_Speech_Output_Task()
{
	global ActionSpeech_Output_Queue
	global ActionSpeech_Output_Stop
	global ActionSpeech_Output_CurrentExecution

	static CurrentVoice
	static AllVoices := []
	static currentCallback
	static teststat

	; if we have to stop speech output, do it now
	if (ActionSpeech_Output_Stop)
	{
		ActionSpeech_Output_Stop := false
		if (CurrentVoice)
		{
			TTS(AllVoices[CurrentVoice], "Stop")
		}
	}
	; is a speech output running?
	if (CurrentVoice)
	{
		; check state of the speech output
		status := TTS(AllVoices[CurrentVoice], "GetStatus")
		
		if (status = "reading" or status = "paused")
		{
			; speech output is running. We will do nothing
			currentlyReading := true
		}
		Else
		{
			; speech output has finished. Call callback function
			%currentCallback%("normal")
			CurrentVoice := ""
		}
	}

	; continue only if speech output is not running
	if (not currentlyReading)
	{
		; get one entry from speech list
		QueueItem := ActionSpeech_Output_Queue.RemoveAt(1)
		if (QueueItem)
		{
			currentCallback := QueueItem.callback

			; create a unique voice identification string.
			; We will use it to store the created voice into a global variable. And we will reuse the created voice if the element is started again with same parameters.
			VoiceIdentification := QueueItem.TTSEngine "#"  QueueItem.volume "#"  QueueItem.speed "#" QueueItem.pitch
			
			;Create voice if not created yet
			if (not AllVoices[VoiceIdentification])
			{
				; voice with those parameters was not created yet. Create a new one.
				createdVoice := TTS_CreateVoice(QueueItem.TTSEngine, QueueItem.speed, QueueItem.volume, QueueItem.pitch)

				; check for errors
				if not (createdVoice)
				{
					if (currentCallback)
						%currentCallback%("exception", x_lang("Could not find TTS engine '%1%'", QueueItem.TTSEngine))
					return
				}

				; store the created voice into a global variable
				AllVoices[VoiceIdentification] := createdVoice
			}
			
			;Do the speech output
			try
			{
				; start speech output
				TTS(AllVoices[VoiceIdentification], "Speak", QueueItem.TextToSpeak)
				ActionSpeech_Output_CurrentExecution := QueueItem.uniqueID
				CurrentVoice := VoiceIdentification
				if not (QueueItem.wait)
				{
					; the option "wait" is not set. We will call the callback function right now
					%currentCallback%("normal")
					currentCallback := ""
				}
			}
			catch
			{
				; an error occured. return with exception
				%currentCallback%("exception", x_lang("Error on speech output"))
				return
			}
		}
	}
}