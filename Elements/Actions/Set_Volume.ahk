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
	
	
	parametersToEdit:=["Label|" lang("Action"),"Radio|1|Action|" lang("Set mute state") ";" lang("Set a specific volume") ";" lang("Increase or decrease volume"),"Label|" lang("Mute settings"),"Radio|1|Mute|" lang("Mute on") ";" lang("Mute off") ";" lang("Toggle") ,"Label|" lang("Absolute volume"),"Slider|80|volume|Range0-100 TickInterval10 tooltip","Label|" lang("Relative volume"),"Slider|10|volumeRelative|Range-100-100 TickInterval10 tooltip"]
	
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
