iniAllActions.="Play_Sound|" ;Add this action to list of all actions on initialisation

runActionPlay_Sound(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempSound

	if (%ElementID%WhitchSound=1)
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
		SoundPlay,% v_replaceVariables(InstanceID,ThreadID,%ElementID%soundfile)
	if errorlevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
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

getParametersActionPlay_Sound()
{
	global
	
	parametersToEdit:=["Label|" lang("Select sound"),"Radio|6|WhitchSound|" lang("Simple beep") ";" lang("Hand (stop/error)") ";" lang("Question") ";" lang("Exclamation") ";" lang("Asterisk (info)") ";" lang("Sound file"),"File||soundfile|" lang("Select a sound file") "|1"]
	return parametersToEdit
}

GenerateNameActionPlay_Sound(ID)
{
	global
	;MsgBox % %ID%text_to_show
	local returnstring
	if (GUISettingsOfElement%ID%WhitchSound1 = 1 )
	{
		returnstring:= lang("Simple beep")
	}
	else if (GUISettingsOfElement%ID%WhitchSound2 = 1 )
	{
		returnstring:= lang("Hand (stop/error)")
	}
	else if (GUISettingsOfElement%ID%WhitchSound3 = 1 )
	{
		returnstring:=lang("Question") 
	}
	else if (GUISettingsOfElement%ID%WhitchSound4 = 1 )
	{
		returnstring:= lang("Exclamation")
	}
	else if (GUISettingsOfElement%ID%WhitchSound5 = 1 )
	{
		returnstring:= lang("Asterisk (info)")
	}
	else if (GUISettingsOfElement%ID%WhitchSound6 = 1 )
	{
		returnstring:= GUISettingsOfElement%ID%soundfile
	}
	
	return lang("Play_Sound") ": " returnstring
	
}

CheckSettingsActionPlay_Sound(ID)
{
	
	static playedSound
	;MsgBox % "GUISettingsOfElement%ID%IdentifyControlBy " GUISettingsOfElement%ID%IdentifyControlBy
	if (GUISettingsOfElement%ID%WhitchSound6 = 1)
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%soundfile
		GuiControl,Enable,GUISettingsOfElementbuttonSelectFile_%ID%_soundfile
	}
	else
	{
		
		GuiControl,Disable,GUISettingsOfElementbuttonSelectFile_%ID%_soundfile
		GuiControl,Disable,GUISettingsOfElement%ID%soundfile
	}
	if (GUISettingsOfElement%ID%WhitchSound5 = 1 && playedSound!=5 )
	{
		if playedSound!=
			SoundPlay,*64
		playedSound=5
	}
	else if (GUISettingsOfElement%ID%WhitchSound4 = 1 && playedSound!=4 )
	{
		if playedSound!=
			SoundPlay,*48
		playedSound=4
	}
	if (GUISettingsOfElement%ID%WhitchSound3 = 1 && playedSound!=3 )
	{
		if playedSound!=
			SoundPlay,*32
		playedSound=3
	}
	if (GUISettingsOfElement%ID%WhitchSound2 = 1 && playedSound!=2 )
	{
		if playedSound!=
			SoundPlay,*16
		playedSound=2
	}
	if (GUISettingsOfElement%ID%WhitchSound1 = 1 && playedSound!=1 )
	{
		if playedSound!=
			SoundPlay,*-1
		playedSound=1
	}
	if (GUISettingsOfElement%ID%WhitchSound6 = 1 && playedSound!=6 )
	{
		playedSound=6
	}
	
}
