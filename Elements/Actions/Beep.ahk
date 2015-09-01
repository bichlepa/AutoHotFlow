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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Frequency in Hz")})
	parametersToEdit.push({type: "edit", id: "frequency", default: 523, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Duration in ms")})
	parametersToEdit.push({type: "edit", id: "duration", default: 150, content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionBeep(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Beep") ": " GUISettingsOfElement%id%frequency " " lang("Hz") " " GUISettingsOfElement%id%duration " " lang("ms")
	
}


