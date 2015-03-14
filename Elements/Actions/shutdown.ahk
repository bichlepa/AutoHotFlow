iniAllActions.="Shutdown|" ;Add this action to list of all actions on initialisation

runActionShutdown(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	shutdown,9 ;Shutdown and power off
	
	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionShutdown()
{
	return lang("Shutdown_Computer")
}
getCategoryActionShutdown()
{
	return lang("Power")
}

getParametersActionShutdown()
{
	global
	
	parametersToEdit=
	return parametersToEdit
}

GenerateNameActionShutdown(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Shutdown_Computer")
	
}