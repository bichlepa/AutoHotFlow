iniAllTriggers.="Start_Up|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerStart_Up(ElementID)
{
	global
	
	if EnableFlowOptions=StartUp
	{
		
		EnableFlowOptions=
		settimer,r_startRun,-1000
	}
	
	
}

getParametersTriggerStart_Up()
{
	
	parametersToEdit:=[]
	
	return parametersToEdit
}

getNameTriggerStart_Up()
{
	return lang("Start_up")
}
getCategoryTriggerStart_Up()
{
	return lang("Power")
}



DisableTriggerStart_Up(ID)
{
	
	
	
	
}

GenerateNameTriggerStart_Up(ID)
{
	return lang("Start_up") 
	
}

