iniAllActions.="Empty_recycle_bin|" ;Add this action to list of all actions on initialisation

runActionEmpty_recycle_bin(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	if %ElementID%AllDrives=1
		FileRecycleEmpty
	else
		FileRecycleEmpty, % v_replaceVariables(InstanceID,ThreadID,%ElementID%Drive)
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionEmpty_recycle_bin()
{
	return lang("Empty_recycle_bin")
}
getCategoryActionEmpty_recycle_bin()
{
	return lang("Files")
}

getParametersActionEmpty_recycle_bin()
{
	global
	
	parametersToEdit:=["Label|" lang("Which drive"),"Radio|1|AllDrives|" lang("All drives") ";" lang("Specified drive"),"Folder||drive|" lang("Select the root Folder of a drive") "|2"]
	return parametersToEdit
}

GenerateNameActionEmpty_recycle_bin(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Empty_recycle_bin")
	
}

CheckSettingsActionEmpty_recycle_bin(ID)
{
	if (GUISettingsOfElement%ID%AllDrives1 = 1)
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%drive
	}
	else
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%drive
	}
	
	
}