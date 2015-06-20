iniAllTriggers.="Periodic_timer|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerPeriodic_timer(ElementID)
{
	global
	local tempDuration
	
	if %ElementID%Unit=1 ;Milliseconds
		tempDuration:=%ElementID%Intervall_S
	else if %ElementID%Unit=2 ;Seconds
		tempDuration:=%ElementID%Intervall_S * 1000
	else if %ElementID%Unit=3 ;minutes
		tempDuration:=%ElementID%Intervall_S * 60000
	
	
	settimer,TriggerPeriodic_TimerStart,%tempDuration%
	
	
}

getParametersTriggerPeriodic_timer()
{
	
	parametersToEdit:=["Label|" lang("Time interval"),"Text|10|Intervall_S","Radio|2|Unit|" lang("Milliseconds") ";" lang("Seconds") ";" lang("Minutes")]
	
	
	return parametersToEdit
}

getNameTriggerPeriodic_timer()
{
	return lang("Periodic_timer")
}
getCategoryTriggerPeriodic_timer()
{
	return lang("Time")
}



DisableTriggerPeriodic_timer(ID)
{
	
	settimer,TriggerPeriodic_TimerStart,off
	
	
}

GenerateNameTriggerPeriodic_timer(ID)
{
	return lang("Periodic_timer") " " lang("Every %1% seconds",GUISettingsOfElement%ID%Intervall_S)
	
}

goto,JumpOverTriggerPeriodic_TimerStart

TriggerPeriodic_TimerStart:
goto,r_startRun

return

JumpOverTriggerPeriodic_TimerStart:
temp= ;Do nothing