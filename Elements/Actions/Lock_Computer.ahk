iniAllActions.="Lock_Computer|" ;Add this action to list of all actions on initialisation

runActionLock_Computer(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	DllCall("LockWorkStation")
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionLock_Computer()
{
	return lang("Lock_computer")
}
getCategoryActionLock_Computer()
{
	return lang("Power")
}

getParametersActionLock_Computer()
{
	global
	
	parametersToEdit=
	return parametersToEdit
}

GenerateNameActionLock_Computer(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Lock_computer")
	
}