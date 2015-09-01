iniAllActions.="Tooltip|" ;Add this action to list of all actions on initialisation

runActionTooltip(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempDuration
	runActionTooltip_Oldx=
	runActionTooltip_Oldy=
	runActionTooltip_Text:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text,"normal")
	ToolTip,%runActionTooltip_Text%,,,13
	if %ElementID%follow_mouse =1
		SetTimer,runActionTooltip_follow_mouse,10,,,13
	
	if %ElementID%Unit=1 ;Milliseconds
		tempDuration:=%ElementID%duration
	else if %ElementID%Unit=2 ;Seconds
		tempDuration:=%ElementID%duration * 1000
	else if %ElementID%Unit=3 ;minutes
		tempDuration:=%ElementID%duration * 60000
	
	
	SetTimer,runActionTooltip_RemoveTooltip,-%tempDuration%
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
	runActionTooltip_follow_mouse:
	MouseGetPos,runActionTooltip_MouseX,runActionTooltip_MouseY
	if !(runActionTooltip_Oldy=runActionTooltip_Mousey and runActionTooltip_Oldx=runActionTooltip_MouseX)
	{
		runActionTooltip_Oldy:=runActionTooltip_Mousey 
		runActionTooltip_Oldx:=runActionTooltip_MouseX
		ToolTip,%runActionTooltip_Text%,,,13
	}
	return
	runActionTooltip_RemoveTooltip:
	SetTimer,runActionTooltip_follow_mouse,off
	ToolTip,,,,13
	
	
	return
}
getNameActionTooltip()
{
	return lang("Tooltip")
}
getCategoryActionTooltip()
{
	return lang("User_interaction")
}

getParametersActionTooltip()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Text_to_show")})
	parametersToEdit.push({type: "Edit", id: "text", default: lang("Message"), multiline: true, content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Duration")})
	parametersToEdit.push({type: "Number", id: "duration", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes")]})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "follow_mouse", default: 1, label: lang("Follow_Mouse")})

	return parametersToEdit
}

GenerateNameActionTooltip(ID)
{
	global
	local temptext
	local duration
	if GUISettingsOfElement%ID%Unit1
		duration:=GUISettingsOfElement%ID%duration " " lang("ms #Milliseconds")
	if GUISettingsOfElement%ID%Unit2
		duration:=GUISettingsOfElement%ID%duration " " lang("s #Seconds")
	if GUISettingsOfElement%ID%Unit3
		duration:=GUISettingsOfElement%ID%duration " " lang("m #Minutes")
	
	if GUISettingsOfElement%ID%follow_mouse=1
		temptext:=lang("Follow_Mouse") "`n"
	else
		temptext=
	return lang("Tooltip") ": " GUISettingsOfElement%ID%text "`n" duration "`n" temptext
	
}