iniAllTriggers.="User_Idle_Time|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerUser_Idle_Time(ElementID)
{
	global
	if (!IsObject(TriggerUser_Idle_TimeCurrentTimes))
		TriggerUser_Idle_TimeCurrentTimes:=Object()


	 if %ElementID%Unit=1 ;Seconds
		tempDuration:=%ElementID%Intervall_S 
	else if %ElementID%Unit=2 ;minutes
		tempDuration:=%ElementID%Intervall_S * 60
	else if %ElementID%Unit=3 ;hours
		tempDuration:=%ElementID%Intervall_S * 60*60
	
	
	TriggerUser_Idle_TimeCurrentTimes.insert( ElementID ,tempDuration) 
	SetTimer,TriggerUser_Idle_TimeLoop,1000
	
	return
	
	TriggerUser_Idle_TimeLoop:
	
	
	for tempUser_Idle_Timeid, tempUser_Idle_TimeValue in TriggerUser_Idle_TimeCurrentTimes ;loop through all sleepTimes and look whether the sleep time is over
	{
		
		if (A_TimeIdlePhysical>(tempUser_Idle_TimeValue*1000))
		{
			if (%tempUser_Idle_Timeid%TriggerUser_Idle_TimeHasRun!=true)
			{
				%tempUser_Idle_Timeid%TriggerUser_Idle_TimeHasRun:=true
				SetTimer,r_startRun,-1 ;Run flow
			}
			
		}
		else
			%tempUser_Idle_Timeid%TriggerUser_Idle_TimeHasRun:=false
		
		
		
	}
	
	
	
	;MsgBox % nextTimerRun

	return
}

getParametersTriggerUser_Idle_Time()
{
	
	parametersToEdit:=["Label|" lang("Period of time"),"Text|10|Intervall_S","Radio|2|Unit|"  lang("Seconds") ";" lang("Minutes") ";" lang("Hours")]
	
	
	return parametersToEdit
}

getNameTriggerUser_Idle_Time()
{
	return lang("User_Idle_Time")
}
getCategoryTriggerUser_Idle_Time()
{
	return lang("User_interaction") "|" lang("Time")
}



DisableTriggerUser_Idle_Time(ID)
{
	
	settimer,TriggerUser_Idle_TimeLoop,off
	TriggerTime_of_dayCurrentTimes.remove(ID)
	
}

GenerateNameTriggerUser_Idle_Time(ID)
{
	return lang("User_Idle_Time") "`n"  lang("After %1% seconds",GUISettingsOfElement%ID%Intervall_S)
	
}

