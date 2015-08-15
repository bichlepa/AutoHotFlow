iniAllTriggers.="User_Idle_Time|" ;Add this trigger to list of all triggers on initialisation

TriggerUser_Idle_TimeCurrentTimes:=Object()

EnableTriggerUser_Idle_Time(ElementID)
{
	global
	local temp
	local tempDuration:=v_EvaluateExpression(0,0,%ElementID%Intervall_S)
	
	
	if not tempDuration is number
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! The interval is not a number.")
		MsgBox,16,% lang("Error"),% lang("Trigger '%1%' couln't be activated!", %ElementID%name) " " lang("The interval is not a number.") 
		return
	}
	
	
	local tempTriggerParams:=Object()
	tempTriggerParams["ElementID"]:=ElementID
	tempTriggerParams["Method"]:=%ElementID%method
	
	if %ElementID%Unit=1 ;Seconds
		tempDuration:=tempDuration
	else if %ElementID%Unit=2 ;minutes
		tempDuration:=tempDuration * 60
	else if %ElementID%Unit=3 ;hours
		tempDuration:=tempDuration * 60*60
	
	tempTriggerParams["Duration"]:=tempDuration
	
	TriggerUser_Idle_TimeCurrentTimes.push(tempTriggerParams) 
	SetTimer,TriggerUser_Idle_TimeLoop,1000
	
	return
	
	TriggerUser_Idle_TimeLoop:
	
	;~ ToolTip,% A_TimeIdlePhysical " - " A_TimeIdle "`n`n" strobj(TriggerUser_Idle_TimeCurrentTimes)
	
	for tempkey, tempvalue in TriggerUser_Idle_TimeCurrentTimes ;loop through all sleepTimes and look whether the sleep time is over
	{
		tempUser_Idle_Timeid:=tempvalue["ElementID"]
		tempUser_Idle_TimeMethod:=tempvalue["Method"]
		tempUser_Idle_TimeDuration:=tempvalue["Duration"]
		;~ ToolTip %tempUser_Idle_Timeid% %tempUser_Idle_TimeMethod% %tempUser_Idle_TimeDuration%
		if (((tempUser_Idle_TimeMethod=1) and (A_TimeIdle>(tempUser_Idle_TimeDuration*1000))) or ((tempUser_Idle_TimeMethod=2) and (A_TimeIdlePhysical>(tempUser_Idle_TimeDuration*1000))))
		{
			if (%tempUser_Idle_Timeid%TriggerUser_Idle_TimeHasRun!=true)
			{
				%tempUser_Idle_Timeid%TriggerUser_Idle_TimeHasRun:=true
				r_Trigger(tempUser_Idle_Timeid)
				
			}
			
		}
		else
			%tempUser_Idle_Timeid%TriggerUser_Idle_TimeHasRun:=false
		
	}
	
	;MsgBox % nextTimerRun

	return
}



DisableTriggerUser_Idle_Time(ID)
{
	global
	for tempnumber, tempobject in TriggerUser_Idle_TimeCurrentTimes
	{
		if (tempobject["elementid"]=ID)
		{
			
			TriggerUser_Idle_TimeCurrentTimes.delete(tempnumber)
		}
		
	}
	
	
	
}

getParametersTriggerUser_Idle_Time()
{
	
	parametersToEdit:=["Label|" lang("Period of time"),"Text|10|Intervall_S","Radio|2|Unit|"  lang("Seconds") ";" lang("Minutes") ";" lang("Hours"),"Label|" lang("Method"),"Radio|1|Method|"   lang("Method %1%",1) ";" lang("Method %1%",2) ]
	
	
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





GenerateNameTriggerUser_Idle_Time(ID)
{
	return lang("User_Idle_Time") " - "  lang("After %1% seconds",GUISettingsOfElement%ID%Intervall_S)
	
}

