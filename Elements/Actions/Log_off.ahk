iniAllActions.="Log_Off|" ;Add this action to list of all actions on initialisation

runActionLog_Off(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	shutdown,0
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionLog_Off()
{
	return lang("Log_off")
}
getCategoryActionLog_Off()
{
	return lang("Power")
}

getParametersActionLog_Off()
{
	global
	
	parametersToEdit:=Object()

	return parametersToEdit
}

GenerateNameActionLog_Off(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Log_off")
	
}