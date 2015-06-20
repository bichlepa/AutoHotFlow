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
	parametersToEdit:=["Label|" lang("Text_to_show"),"MultiLineText|" lang("Message") "|text","Label|" lang("Duration"),"Number|2|duration","Radio|2|Unit|" lang("Milliseconds") ";" lang("Seconds") ";" lang("Minutes"),"Label|" lang("Options"),"Checkbox|1|follow_mouse|" lang("Follow_Mouse")]
	
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