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
	parametersToEdit:=["Label|" lang("Keys_or_text_to_send"),"Checkbox|0|RawMode|" lang("Raw mode"),"Text||KeysToSend","Label|" lang("Send mode"),"Radio|1|SendMode|" lang("Input mode") ";" lang("Event mode") ";" lang("Play mode")]
	;,"Label|" lang("Insert_a_keystroke"), "Hotkey||HotkeyToInsert,"Button|customSettingButtonOfActionSend_KeystrokesHotkeyToInsert||" lang("Insert")
	return parametersToEdit
}



GenerateNameActionSend_Keystrokes(ID)
{
	global
	
	return % lang("Send keystrokes") "`n" GUISettingsOfElement%ID%KeysToSend
	
}