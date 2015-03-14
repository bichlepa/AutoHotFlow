iniAllActions.="Speech_output|" ;Add this action to list of all actions on initialisation

runActionSpeech_output(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempDuration
	
	local runActionSpeech_Engine:=v_replaceVariables(InstanceID,%ElementID%TTSEngine)
	local runActionSpeech_Volume:=v_replaceVariables(InstanceID,%ElementID%Volume)
	local runActionSpeech_Pitch:=v_replaceVariables(InstanceID,%ElementID%Pitch)
	local runActionSpeech_Speed:=v_replaceVariables(InstanceID,%ElementID%Speed)
	local runActionSpeech_output_Text:=v_replaceVariables(InstanceID,%ElementID%text,"normal")
	
	
	if ActionSpeech_Engine_lastreadingvoice
	{
		if %ElementID%WaitUntilPreviousFinished
		{
			Loop
			{
				
				if (TTS(ActionSpeech_Engine_lastreadingvoice, "GetStatus")!="reading" or stopRun=true)
					break
				sleep,100
			}
		}
		else 
			TTS(ActionSpeech_Engine_lastreadingvoice, "Stop")
			
	}
	
	
	if (stopRun!=true)
	{
		;Create voice if not created yet
		if (runActionSpeech_Engine%ElementID%VoiceName!=runActionSpeech_Engine runActionSpeech_Volume runActionSpeech_Speed runActionSpeech_Pitch )
		{
			runActionSpeech_Engine%ElementID%Voice:=TTS_CreateVoice(runActionSpeech_Engine, runActionSpeech_Speed, runActionSpeech_Volume, runActionSpeech_Pitch)
			
			runActionSpeech_Engine%ElementID%VoiceName:=runActionSpeech_Engine runActionSpeech_Volume runActionSpeech_Speed runActionSpeech_Pitch 
			
		}
		

		
		TTS(runActionSpeech_Engine%ElementID%Voice, "Speak", runActionSpeech_output_Text)
		
		if %ElementID%WaitUntilCurrentFinishes
		{
			Loop
			{
				sleep,100
				if (TTS(runActionSpeech_Engine%ElementID%Voice, "GetStatus")!="reading" or stopRun=true)
					break
			}
		}
		ActionSpeech_Engine_lastreadingvoice:=runActionSpeech_Engine%ElementID%Voice
		
	}
	if (stopRun=true)
	{
		TTS(ActionSpeech_Engine_lastreadingvoice, "Stop")
		TTS(runActionSpeech_Engine%ElementID%Voice, "Stop")
	}
	
	ActionSpeech_output_now_Speaking:=false
	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	
	return

}
getNameActionSpeech_output()
{
	return lang("Speech_output")
}
getCategoryActionSpeech_output()
{
	return lang("User_interaction") "|" lang("Sound")
}

getParametersActionSpeech_output()
{
	global
	
	parametersToEdit:=["Label|" lang("Text_to_speak"),"MultiLineText|" lang("Message") "|text","Checkbox|0|WaitUntilPreviousFinished|" lang("Wait until previous speech output has finished (if any)"),"Checkbox|1|WaitUntilCurrentFinishes|" lang("Wait until current speech output finishes"),"Label|" lang("Speech engine"), "DropDownListByName|" TTSDefaultLanguage "|TTSEngine|" TTSList,"Label|" lang("Volume"), "Slider|100|volume|Range0-100 TickInterval10 tooltip","Label|" lang("Speed"), "Slider|0|speed|Range-10-10 TickInterval1 tooltip","Label|" lang("Pitch"), "Slider|0|pitch|Range-10-10 TickInterval1 tooltip"]
	
	return parametersToEdit
}

GenerateNameActionSpeech_output(ID)
{
	global
	
	return lang("Speech_output") ": " GUISettingsOfElement%ID%text
	
}

 ;Search for available Engines
TTSList=

TTSDefaultLanguage=
loop,HKEY_LOCAL_MACHINE,SOFTWARE\Microsoft\Speech\Voices\Tokens,1,1 ;Liest die Registry aus um die verfügbaren Stimmen herauszufinden
{
	RegRead, Reginhalt
	;~ fileappend,subkey:%A_LoopRegSubKey%`nregname:%A_LoopRegName%`nregread:%Reginhalt%`n`n,text.txt ;Alle Registry-Einträge dokumentieren. zum Debuggen
	stringgetpos,a,A_LoopRegName,\,l6
	if errorlevel=1
	if A_LoopRegName=Name
	if Reginhalt<>
	{
		
		if (TTSRightLanguageFound="") ;Wenn man noch keine Stimme gewählt hat, wird automatisch die erste Stimme gewählt
		{
			RegRead, SprachNummer, %A_LoopRegKey%, %A_LoopRegSubKey%,Language  ;Die Sprache herausfinden
			;msgbox,%A_LoopRegSubKey%`n%A_LoopRegName%`nSprachnummer: %SprachNummer% `n A_Language: %A_Language%
			if (SprachNummer = A_Language)
			{
				TTSDefaultLanguage:=Reginhalt
				TTSRightLanguageFound:=true
			}
			else if TTSDefaultLanguage=
				TTSDefaultLanguage:=Reginhalt
				
		}
		TTSList=%TTSList%%Reginhalt%;
		
	}
}
StringTrimRight,TTSList,TTSList,1
;MsgBox % TTSList " Default: " TTSDefaultLanguage
ActionSpeech_output_alreadyGotSpeechEngines:=true
