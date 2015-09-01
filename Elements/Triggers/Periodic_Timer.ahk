iniAllTriggers.="Periodic_timer|" ;Add this trigger to list of all triggers on initialisation

TriggerPeriodic_timer_AllActiveTimersObj:=Object()
TriggerPeriodic_timer_MaxAmountOfTimers:=10

goto,jumpoverPeriodic_timerLabels

EnableTriggerPeriodic_timer(ElementID)
{
	global
	local tempDuration:=v_EvaluateExpression(0,0,%ElementID%Intervall_S)
	local success
	
	
	if not tempDuration is number
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! The interval is not a number.")
		MsgBox,16,% lang("Error"),% lang("Timer '%1%' couln't be activated!", %ElementID%name) " " lang("The interval is not a number.") 
		return
	}
	
	if %ElementID%Unit=1 ;Milliseconds
		tempDuration:=tempDuration
	else if %ElementID%Unit=2 ;Seconds
		tempDuration:=tempDuration * 1000
	else if %ElementID%Unit=3 ;minutes
		tempDuration:=tempDuration * 60000
	
	if not (tempDuration >0)
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! The interval is not greater than 0.")
		MsgBox,16,% lang("Error"),% lang("Trigger '%1%' couln't be activated!", %ElementID%name) " " lang("The interval is not greater than 0.") 
		return
	}
	
	loop %TriggerPeriodic_timer_MaxAmountOfTimers%
	{
		if TriggerPeriodic_timer_AllActiveTimersObj.HasKey("Index" A_Index)
			continue
		else
		{
			
			
			TriggerPeriodic_timer_AllActiveTimersObj["Index" A_Index]:=ElementID
			
			
			settimer,TriggerTriggerPeriodic_timer%A_Index%,%tempDuration%
			success:=true
			break
		}
	}
	
	if not success
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! Timer couln't be activated. The maximum amount is reached.")
		MsgBox,16,% lang("Error"),% lang("Timer '%1%' couln't be activated!", %ElementID%name) " " lang("The maximum amount is reached.") 
		return
	}
	
}


TriggerTriggerPeriodic_timer1:
TriggerTriggerPeriodic_timer2:
TriggerTriggerPeriodic_timer3:
TriggerTriggerPeriodic_timer4:
TriggerTriggerPeriodic_timer5:
TriggerTriggerPeriodic_timer6:
TriggerTriggerPeriodic_timer7:
TriggerTriggerPeriodic_timer8:
TriggerTriggerPeriodic_timer9:
TriggerTriggerPeriodic_timer10:
StringTrimLeft,tempTriggerPeriodic_timerIndex,A_ThisLabel,28
TriggerTriggerPeriodic_timer(tempTriggerPeriodic_timerIndex)
return

TriggerTriggerPeriodic_timer(Index)
{
	global
	local ElementID:=TriggerPeriodic_timer_AllActiveTimersObj["Index" index]
	
	
	r_Trigger(ElementID)
}

DisableTriggerPeriodic_timer(ID)
{
	global
	local index
	local success
	
	for key, value in TriggerPeriodic_timer_AllActiveTimersObj
	{
		if (value=ID)
		{
			TriggerPeriodic_timer_AllActiveTimersObj.delete(key)
			StringTrimLeft,index,key,5
			success:=true
			break
		}
		
	}
	
	if success
		settimer,TriggerTriggerPeriodic_timer%index%,off
	
	
}

getParametersTriggerPeriodic_timer()
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "label", label:  lang("Time interval")})
	parametersToEdit.push({type: "edit", id: "Intervall_S", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes")], default: 2})

	
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


GenerateNameTriggerPeriodic_timer(ID)
{
	if GUISettingsOfElement%ID%Unit1=1
		return lang("Periodic_timer") " " lang("Every %1% milliseconds",GUISettingsOfElement%ID%Intervall_S)
	else if GUISettingsOfElement%ID%Unit2=1
		return lang("Periodic_timer") " " lang("Every %1% seconds",GUISettingsOfElement%ID%Intervall_S)
	else if GUISettingsOfElement%ID%Unit3=1
		return lang("Periodic_timer") " " lang("Every %1% minutes",GUISettingsOfElement%ID%Intervall_S)
}

jumpoverPeriodic_timerLabels:
temp= ;Do nothing
