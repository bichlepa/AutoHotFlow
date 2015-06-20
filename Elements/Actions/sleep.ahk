iniAllActions.="Sleep|" ;Add this action to list of all actions on initialisation

runActionSleep(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionSleepCurrentSleeps))
		ActionSleepCurrentSleeps:=Object()
	
	
	if %ElementID%Unit=1 ;Milliseconds
		tempActionSleepDuration:=%ElementID%duration
	else if %ElementID%Unit=2 ;Seconds
		tempActionSleepDuration:=%ElementID%duration * 1000
	else if %ElementID%Unit=3 ;minutes
		tempActionSleepDuration:=%ElementID%duration * 60000
	
	ActionSleepCurrentSleeps.insert("Instance_" InstanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance,(A_TickCount + tempActionSleepDuration-10)) ;Save the end time.
	SetTimer,ActionSleepEnd,10
	
	return
	
	ActionSleepEnd:
	
	tempSleepSmallestTime=0
	for tempSleepid, tempSleepEndTime in ActionSleepCurrentSleeps ;loop through all sleepTimes and look whether the sleep time is over
	{
		
		if (tempSleepEndTime<A_TickCount)
		{
			
			StringSplit,tempSleepid,tempSleepid,_
			; tempElement1 = word "instance"
			; tempElement2 = instance id
			; tempElement3 = Thread ID
			; tempElement4 = element id
			; tempElement5 = element id in the instance
			MarkThatElementHasFinishedRunning(tempSleepid2,tempSleepid3,tempSleepid4,tempSleepid5,"normal")

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
	parametersToEdit:=["Label| " lang("Duration"),"Number|2|Duration","Radio|2|Unit|" lang("Milliseconds") ";" lang("Seconds") ";" lang("Minutes")]
	
	return parametersToEdit
}

GenerateNameActionSleep(ID)
{
	global
	local unit
	
	if GUISettingsOfElement%ID%Unit1
		unit:= lang("ms #milliseconds")
	else if GUISettingsOfElement%ID%Unit2
		unit:= lang("s #seconds")
	else if GUISettingsOfElement%ID%Unit3
		unit:= lang("m #minutes")
	
	return % lang("Sleep") "`n" GUISettingsOfElement%ID%Duration " "  unit
	
}