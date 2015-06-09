iniAllActions.="Get_Volume|" ;Add this action to list of all actions on initialisation

runActionGet_Volume(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	
	SoundGet,temp

	v_setVariable(InstanceID,ThreadID,"t_volume",round(temp,1))
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return

}
getNameActionGet_Volume()
{
	return lang("Get_Volume")
}
getCategoryActionGet_Volume()
{
	return lang("Sound")
}

getParametersActionGet_Volume()
{
	global
	
	
	parametersToEdit:=[]
	
	return parametersToEdit
}

GenerateNameActionGet_Volume(ID)
{
	global
	
	return lang("Get_Volume")
}


