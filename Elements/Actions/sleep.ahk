iniAllActions.="Sleep|" ;Add this action to list of all actions on initialisation

runActionSleep(InstanceID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionSleepCurrentSleeps))
		ActionSleepCurrentSleeps:=Object()
	tempActionSleepDuration:=%ElementID%duration
	
	ActionSleepCurrentSleeps.insert("Instance_" InstanceID "_" ElementID "_" ElementIDInInstance,(A_TickCount + tempActionSleepDuration-10)) ;Save the end time.
	SetTimer,ActionSleepEnd,10
	
	return
	
	ActionSleepEnd:
	
	tempSleepSmallestTime=0
	for tempSleepid, tempSleepEndTime in ActionSleepCurrentSleeps ;loop through all sleepTimes and look whether the sleep time is over
	{
		
		if (tempSleepEndTime<A_TickCount)
		{
			
			StringSplit,tempSleepid,tempSleepid,_
			MarkThatElementHasFinishedRunning(tempSleepid2,tempSleepid3,tempSleepid4,"normal")

			ActionSleepCurrentSleeps.remove(tempSleepid)
		}
		
	}
	if (ActionSleepCurrentSleeps.GetCapacity()=0)
		settimer,ActionSleepEnd,off
	
	return
}
getNameActionSleep()
{
	return lang("Sleep")
}
getCategoryActionSleep()
{
	return lang("Flow_control")
}
getParametersActionSleep()
{
	global
	parametersToEdit:=["Label| " lang("Duration_in_ms"),"Number|1000|Duration"]
	
	return parametersToEdit
}

GenerateNameActionSleep(ID)
{
	global
	
	return % lang("Sleep") "`n" GUISettingsOfElement%ID%Duration " ms" 
	
}