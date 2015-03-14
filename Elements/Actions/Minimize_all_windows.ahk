iniAllActions.="Minimize_all_windows|" ;Add this action to list of all actions on initialisation

runActionMinimize_all_windows(InstanceID,ElementID,ElementIDInInstance)
{
	global

	
	if %ElementID%WinMinimizeAllEvent=1
		WinMinimizeAll
	else
		WinMinimizeAllUndo

	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionMinimize_all_windows()
{
	return lang("Minimize_all_windows")
}
getCategoryActionMinimize_all_windows()
{
	return lang("Window")
}

getParametersActionMinimize_all_windows()
{
	global
	
	parametersToEdit:=["Label|" lang("Event"),"Radio|1|WinMinimizeAllEvent|" lang("Minimize all windows") ";" lang("Undo")]
	return parametersToEdit
}

GenerateNameActionMinimize_all_windows(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Minimize_all_windows") ": " GUISettingsOfElement%id%frequency " " lang("Hz") " " GUISettingsOfElement%id%duration " " lang("ms")
	
}


