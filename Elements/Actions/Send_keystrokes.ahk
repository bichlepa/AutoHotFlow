iniAllActions.="Send_Keystrokes|" ;Add this action to list of all actions on initialisation

runActionSend_Keystrokes(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if %ElementID%RawMode=1
		tempRawText={raw}
	else
		tempRawText=
	
	if %ElementID%SendMode=1
		SendInput,% tempRawText %ElementID%KeysToSend
	else if %ElementID%SendMode=2
		SendEvent,% tempRawText %ElementID%KeysToSend
	else if %ElementID%SendMode=3
		SendPlay,% tempRawText %ElementID%KeysToSend
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionSend_Keystrokes()
{
	return lang("Send keystokes")
}
getCategoryActionSend_Keystrokes()
{
	return lang("User_simulation")
}

getParametersActionSend_Keystrokes()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Keys_or_text_to_send")})
	parametersToEdit.push({type: "Checkbox", id: "RawMode", default: 0, label: lang("Raw mode")})
	parametersToEdit.push({type: "Edit", id: "KeysToSend", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Send mode")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, choices: [lang("Input mode"), lang("Event mode"), lang("Play mode")]})

	return parametersToEdit
}



GenerateNameActionSend_Keystrokes(ID)
{
	global
	
	return % lang("Send keystrokes") "`n" GUISettingsOfElement%ID%KeysToSend
	
}