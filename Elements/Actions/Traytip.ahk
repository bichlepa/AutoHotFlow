iniAllActions.="Traytip|" ;Add this action to list of all actions on initialisation

runActionTraytip(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempDuration
	
	runActionTraytip_Text:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text,"normal")
	runActionTraytip_Title:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Title,"normal")
	runActionTraytip_Icon:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Icon)
	
	if runActionTraytip_Title=
		runActionTraytip_Title:=Flowname
	
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Title"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_to_show")})
	parametersToEdit.push({type: "Edit", id: "text", default: lang("Message"), multiline: true, content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Icon")})
	parametersToEdit.push({type: "Radio", id: "Icon", default: 1, choices: [lang("No icon"), lang("Info icon"), lang("Warning icon"), lang("Error icon")]})

	return parametersToEdit
}

GenerateNameActionTraytip(ID)
{
	global
	;MsgBox % %ID%text_to_show

	return lang("Traytip") ": " GUISettingsOfElement%ID%title "`n" GUISettingsOfElement%ID%text
	
}