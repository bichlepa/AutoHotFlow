iniAllActions.="Beep|" ;Add this action to list of all actions on initialisation

runActionBeep(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global



	SoundBeep,% v_replaceVariables(InstanceID,ThreadID,%ElementID%frequency),% v_replaceVariables(InstanceID,ThreadID,%ElementID%duration)

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionBeep()
{
	return lang("Beep")
}
getCategoryActionBeep()
{
	return lang("Sound")
}

getParametersActionBeep()
{
	global
	
	parametersToEdit:=["Label|" lang("Frequency in Hz"),"text|523|frequency","Label|" lang("Duration in ms"),"text|150|duration"]
	return parametersToEdit
}

GenerateNameActionBeep(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Beep") ": " GUISettingsOfElement%id%frequency " " lang("Hz") " " GUISettingsOfElement%id%duration " " lang("ms")
	
}


