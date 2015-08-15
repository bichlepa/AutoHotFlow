iniAllActions.="Traytip|" ;Add this action to list of all actions on initialisation

runActionTraytip(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempDuration
	
	runActionTraytip_Text:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text,"normal")
	runActionTraytip_Title:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Title,"normal")
	runActionTraytip_Icon:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Icon)
	
	
	Traytip,%runActionTraytip_Title%,%runActionTraytip_Text%,,% runActionTraytip_Icon -1
	;if runActionTraytip_Duration>15
		;SetTimer,runActionTraytip_refresh,4000
	
	
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return

}
getNameActionTraytip()
{
	return lang("Traytip")
}
getCategoryActionTraytip()
{
	return lang("User_interaction")
}

getParametersActionTraytip()
{
	global
	parametersToEdit:=["Label|" lang("Title"),"Text|" lang("Title") "|title", "Label|" lang("Text_to_show"),"MultiLineText|" lang("Message") "|text","Label|" lang("Icon"),"Radio|1|Icon|" lang("No icon") ";" lang("Info icon") ";" lang("Warning icon") ";" lang("Error icon")]
	
	return parametersToEdit
}

GenerateNameActionTraytip(ID)
{
	global
	;MsgBox % %ID%text_to_show

	return lang("Traytip") ": " GUISettingsOfElement%ID%title "`n" GUISettingsOfElement%ID%text
	
}