iniAllTriggers.="Periodic_timer|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerPeriodic_timer(ElementID)
{
	global
	
	settimer,TriggerPeriodic_TimerStart,% %ElementID%Intervall_S * 1000
	
	
}

getParametersTriggerPeriodic_timer()
{
	
	parametersToEdit:=["Label|" lang("Time in Seconds"),"Text|10|Intervall_S"]
	
	
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