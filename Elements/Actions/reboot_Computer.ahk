iniAllActions.="Reboot_Computer|" ;Add this action to list of all actions on initialisation

runActionReboot_Computer(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	shutdown,2
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionReboot_Computer()
{
	return lang("Reboot_computer")
}
getCategoryActionReboot_Computer()
{
	return lang("Power")
}

getParametersActionReboot_Computer()
{
	global
	
	parametersToEdit:=Object()

	return parametersToEdit
}

GenerateNameActionReboot_Computer(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Reboot_computer")
	
}