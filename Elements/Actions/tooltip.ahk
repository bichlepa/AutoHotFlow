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
	
	tempDuration:=%ElementID%duration
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
	parametersToEdit:=["Label|" lang("Text_to_show"),"MultiLineText|" lang("Message") "|text","Label|" lang("Duration_ms"),"Number|1000|duration","Checkbox|1|follow_mouse|" lang("Follow_Mouse")]
	
	return parametersToEdit
}

GenerateNameActionTooltip(ID)
{
	global
	
	if GUISettingsOfElement%ID%follow_mouse=1
		temptext:=lang("Follow_Mouse") "`n"
	else
		temptext=
	return lang("Tooltip") ": " GUISettingsOfElement%ID%text "`n" GUISettingsOfElement%ID%duration " ms`n" temptext
	
}