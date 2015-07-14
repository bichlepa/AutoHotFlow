iniAllActions.="Beep|" ;Add this action to list of all actions on initialisation

runActionBeep(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local frequency:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%frequency)
	local duration:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%duration)

	if frequency is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Frequency is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Frequency")))
		return
	}
	if duration is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Duration is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Duration")))
		return
	}
	SoundBeep,% frequency,% duration

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


