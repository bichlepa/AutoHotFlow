iniAllActions.="Hibernate_Computer|" ;Add this action to list of all actions on initialisation

runActionHibernate_Computer(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0) ;Hibernate
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionHibernate_Computer()
{
	return lang("Hibernate_computer")
}
getCategoryActionHibernate_Computer()
{
	return lang("Power")
}

getParametersActionHibernate_Computer()
{
	global
	
	parametersToEdit:=Object()

	return parametersToEdit
}

GenerateNameActionHibernate_Computer(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Hibernate_computer")
	
}