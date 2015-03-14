iniAllActions.="Set_Volume|" ;Add this action to list of all actions on initialisation

runActionSet_Volume(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	if %ElementID%Relatively
	{
		temp:=v_replaceVariables(InstanceID,%ElementID%volumeRelative)
		if temp<0
			SoundSet,v_replaceVariables(InstanceID,%ElementID%volumeRelative)
		else
			SoundSet,"+" v_replaceVariables(InstanceID,%ElementID%volumeRelative)
	}
	else
	{
		SoundSet,v_replaceVariables(InstanceID,%ElementID%volume)
	}
	
	SoundGet,temp
	v_setVariable(InstanceID,"t_volume",round(temp,1))
	
	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
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
	
	
	parametersToEdit:=["Label|" lang("Volume"),"Checkbox|0|Relatively|" lang("Change relatively"),"Slider|80|volume|Range0-100 TickInterval10 tooltip","Slider|10|volumeRelative|Range-100-100 TickInterval10 tooltip"]
	
	return parametersToEdit
}

GenerateNameActionSet_Volume(ID)
{
	global
	if GUISettingsOfElement%id%Relatively
	{
		if GUISettingsOfElement%ID%volumeRelative >=0
			return lang("Set_Volume") ": " lang("Increase by %1%",GUISettingsOfElement%ID%volumeRelative) 
		if GUISettingsOfElement%ID%volumeRelative <0
			return lang("Set_Volume") ": " lang("Decrease by %1%",GUISettingsOfElement%ID%volumeRelative) 
	}
	else
		return lang("Set_Volume") ": " GUISettingsOfElement%ID%volume
}

CheckSettingsActionSet_Volume(ID)
{
	
	
	if (GUISettingsOfElement%ID%Relatively = 0)
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%volume
		GuiControl,Disable,GUISettingsOfElement%ID%volumeRelative
	}
	else
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%volume
		GuiControl,Enable,GUISettingsOfElement%ID%volumeRelative
	}
	
	
}
