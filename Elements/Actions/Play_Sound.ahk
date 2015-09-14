iniAllActions.="Play_Sound|" ;Add this action to list of all actions on initialisation

runActionPlay_Sound(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath

	if (%ElementID%WhitchSound=1) ;Stupid misspelling :-(
		SoundPlay,*-1
	else if (%ElementID%WhitchSound=2)
		SoundPlay,*16
	else if (%ElementID%WhitchSound=3)
		SoundPlay,*32
	else if (%ElementID%WhitchSound=4)
		SoundPlay,*48
	else if (%ElementID%WhitchSound=5)
		SoundPlay,*64
	else if (%ElementID%WhitchSound=6)
	{
		tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%soundfile)
		if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
			tempPath:=SettingWorkingDir "\" tempPath
		SoundPlay,% tempPath
		
	}
	if errorlevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Sound could not be played")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Sound could not be played") )
		return
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionPlay_Sound()
{
	return lang("Play_Sound")
}
getCategoryActionPlay_Sound()
{
	return lang("Sound")
}

getParametersActionPlay_Sound(shouldInitialize = false)
{
	global
	
	if shouldInitialize 
	{
		local listOfSysSounds:=Object()
		loop, %a_windir%\media\*
		{
			listOfSysSounds.Insert(a_loopfilename)
		}
	}
	
	
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Select sound")})
	parametersToEdit.push({type: "Radio", id: "WhichSound", default: 1, choices: [lang("System sound"), lang("Sound file")]})
	parametersToEdit.push({type: "dropdown", id: "systemSound", default: "tada.wav", choices: listOfSysSounds, result: "name"})
	parametersToEdit.push({type: "File", id: "soundfile", label: lang("Select a sound file"), options: 1})
	parametersToEdit.push({type: "Label", label: lang("Preview")})
	parametersToEdit.push({type: "button", id: "stopSoundNow",  goto: "ActionPlay_SoundStopSoundNow", label: lang("Stop playback now")})

	return parametersToEdit
}

GenerateNameActionPlay_Sound(ID)
{
	global
	;MsgBox % %ID%text_to_show
	local returnstring
	if (GUISettingsOfElement%ID%WhichSound1 = 1 )
	{
		returnstring:=GUISettingsOfElement%ID%systemSound
	}
	else if (GUISettingsOfElement%ID%WhichSound2 = 1 )
	{
		returnstring:= GUISettingsOfElement%ID%soundfile
	}
	
	
	return lang("Play_Sound") ": " returnstring
	
}

CheckSettingsActionPlay_Sound(ID)
{
	global

	static playedSound
	;MsgBox % "GUISettingsOfElement%ID%IdentifyControlBy " GUISettingsOfElement%ID%IdentifyControlBy
	if (GUISettingsOfElement%ID%WhichSound2 = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%systemSound
		GuiControl,Enable,GUISettingsOfElement%ID%soundfile
		GuiControl,Enable,GUISettingsOfElementbuttonSelectFile_%ID%_soundfile
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%systemSound
		GuiControl,Disable,GUISettingsOfElementbuttonSelectFile_%ID%_soundfile
		GuiControl,Disable,GUISettingsOfElement%ID%soundfile
	}
	if (GUISettingsOfElement%ID%WhichSound1 = 1 and playedSound!=GUISettingsOfElement%ID%systemSound and openingElementSettingsWindow=false)
	{
		playedSound:=GUISettingsOfElement%ID%systemSound
		if playedSound!=
		{
			
			SoundPlay,%a_windir%\media\%playedSound%
		}
		
	}
	
	
}

ActionPlay_SoundStopSoundNow()
{
	SoundPlay,stoooooooop
}

