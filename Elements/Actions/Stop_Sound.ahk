iniAllActions.="Stop_Sound|" ;Add this action to list of all actions on initialisation

runActionStop_Sound(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	SoundPlay,-
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionStop_Sound()
{
	return lang("Stop_Sound")
}
getCategoryActionStop_Sound()
{
	return lang("Sound")
}

getParametersActionStop_Sound()
{
	global
	
	parametersToEdit:=[]
	return parametersToEdit
}

GenerateNameActionStop_Sound(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Stop_Sound")
	
}