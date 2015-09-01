iniAllActions.="Set_Volume|" ;Add this action to list of all actions on initialisation

runActionSet_Volume(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	if %ElementID%Action=3
	{
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%volumeRelative)
		if temp<0
			SoundSet,v_replaceVariables(InstanceID,ThreadID,%ElementID%volumeRelative)
		else
			SoundSet,"+" v_replaceVariables(InstanceID,ThreadID,%ElementID%volumeRelative)
	}
	else if %ElementID%Action=2
	{
		SoundSet,v_replaceVariables(InstanceID,ThreadID,%ElementID%volume)
	}
	else if %ElementID%Action=1
	{
		if %ElementID%Mute=1
			SoundSet,1,,mute
		else if %ElementID%Mute=2
			SoundSet,0,,mute
		else if %ElementID%Mute=3
			SoundSet,+1,,mute
	}
	
	SoundGet,temp
	v_setVariable(InstanceID,ThreadID,"a_SoundVolume",round(temp,1),,true)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return

}
getNameActionSet_Volume()
{
	return lang("Set_Volume")
}
getCategoryActionSet_Volume()
{
	return lang("Sound")
}

getParametersActionSet_Volume()
{
	global
	
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "Action", default: 1, choices: [lang("Set mute state"), lang("Set a specific volume"), lang("Increase or decrease volume")]})
	parametersToEdit.push({type: "Label", label: lang("Mute settings")})
	parametersToEdit.push({type: "Radio", id: "Mute", default: 1, choices: [lang("Mute on"), lang("Mute off"), lang("Toggle")]})
	parametersToEdit.push({type: "Label", label: lang("Absolute volume")})
	parametersToEdit.push({type: "Slider", id: "volume", default: 80, options: "Range0-100 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Relative volume")})
	parametersToEdit.push({type: "Slider", id: "volumeRelative", default: 10, options: "Range-100-100 TickInterval10 tooltip"})

	return parametersToEdit
}

GenerateNameActionSet_Volume(ID)
{
	global
	if GUISettingsOfElement%id%Action3
	{
		if GUISettingsOfElement%ID%volumeRelative >=0
			return lang("Set_Volume") ": " lang("Increase by %1%",GUISettingsOfElement%ID%volumeRelative) 
		if GUISettingsOfElement%ID%volumeRelative <0
			return lang("Set_Volume") ": " lang("Decrease by %1%",GUISettingsOfElement%ID%volumeRelative) 
	}
	else if GUISettingsOfElement%id%Action2
		return lang("Set_Volume") ": " GUISettingsOfElement%ID%volume
	else if GUISettingsOfElement%id%Action1
	{
		if GUISettingsOfElement%id%Mute1
			return lang("Set_Volume") ": " lang("Mute on")
		if GUISettingsOfElement%id%Mute2
			return lang("Set_Volume") ": " lang("Mute off")
		if GUISettingsOfElement%id%Mute3
			return lang("Set_Volume") ": " lang("Toggle mute")
	}
}

CheckSettingsActionSet_Volume(ID)
{
	
	
	if GUISettingsOfElement%ID%Action2
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%Mute1
		GuiControl,Disable,GUISettingsOfElement%ID%Mute2
		GuiControl,Disable,GUISettingsOfElement%ID%Mute3
		GuiControl,Enable,GUISettingsOfElement%ID%volume
		GuiControl,Disable,GUISettingsOfElement%ID%volumeRelative
	}
	else if GUISettingsOfElement%ID%Action3
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%Mute1
		GuiControl,Disable,GUISettingsOfElement%ID%Mute2
		GuiControl,Disable,GUISettingsOfElement%ID%Mute3
		GuiControl,Disable,GUISettingsOfElement%ID%volume
		GuiControl,Enable,GUISettingsOfElement%ID%volumeRelative
	}
	else if GUISettingsOfElement%ID%Action1
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%Mute1
		GuiControl,Enable,GUISettingsOfElement%ID%Mute2
		GuiControl,Enable,GUISettingsOfElement%ID%Mute3
		GuiControl,Disable,GUISettingsOfElement%ID%volume
		GuiControl,Disable,GUISettingsOfElement%ID%volumeRelative
	}
	
	
}
