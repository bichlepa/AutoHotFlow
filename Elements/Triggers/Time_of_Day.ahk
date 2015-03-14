iniAllTriggers.="Time_of_day|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerTime_of_day(ElementID)
{
	global
	if (!IsObject(TriggerTime_of_dayCurrentTimes))
		TriggerTime_of_dayCurrentTimes:=Object()
	tempTriggerTime_of_dayTimeStamp:=%ElementID%time
	
	if (%ElementID%WeekDays!="") ;If at least one day is selected
		TriggerTime_of_dayCurrentTimes.insert( ElementID ,tempTriggerTime_of_dayTimeStamp) 
	SetTimer,TriggerTime_of_dayLoop,1000
	
	return
	
	TriggerTime_of_dayLoop:
	
	
	for tempTime_of_dayid, tempTime_of_dayEndTime in TriggerTime_of_dayCurrentTimes ;loop through all sleepTimes and look whether the sleep time is over
	{
		;MsgBox %tempTime_of_dayEndTime%
		EnvSub,tempTime_of_dayEndTime,a_now,seconds
		
		if (tempTime_of_dayEndTime<=0) ;If the time is over
		{
			
			if (tempTime_of_dayEndTime>-60) ;If less than 60 seconds passed after the triggertime
			{
				
				SetTimer,r_startRun,-1 ;Run flow
			}
			
			if (%tempTime_of_dayid%WeekDays!="") ;Set a new time
			{
				
				FormatTime,TriggerTime_of_dayNewTimeWithoutDate,tempTime_of_dayEndTime,HHmmss
				loop 8 ;Go through all days of week
				{
					
					TriggerTime_of_dayNewTime:=A_YYYY . A_MM . A_DD . TriggerTime_of_dayNewTimeWithoutDate ;Create a new time and date
					EnvAdd,TriggerTime_of_dayNewTime,% A_Index -1,days
					;MsgBox %TriggerTime_of_dayNewTime%    %TriggerTime_of_dayNewTimeWithoutDate%
					tempdiff:=TriggerTime_of_dayNewTime
					EnvSub,tempdiff,a_now,seconds
					if (tempdiff>0 ) ;Prove that the time is not passed yes. This may occure in the first loop
					{
						FormatTime,tempDayOfWeek,%TriggerTime_of_dayNewTime%,WDay ;find out the weekday of the new day
						;MsgBox % tempDayOfWeek "   " %tempTime_of_dayid%WeekDays
						IfInString,%tempTime_of_dayid%WeekDays,%tempDayOfWeek%
						{
							TriggerTime_of_dayCurrentTimes.insert(tempTime_of_dayid,TriggerTime_of_dayNewTime) ;Add the new time and date as the next trigger time
							
							break
						}
						
						
					}
				}
				
				
			}
			
			
		}
		
	}
	if (TriggerTime_of_dayCurrentTimes.GetCapacity()=0)
		settimer,TriggerTime_of_dayLoop,off
	
	
	;MsgBox % nextTimerRun

	return
	
	
	
}

getParametersTriggerTime_of_day()
{
	
	
	parametersToEdit:=["Label|" lang("Weekdays"), "Weekdays|1234567|WeekDays","Label|" lang("Time of day"),"TimeOfDay|1234567|Time"]
	
	return parametersToEdit
}

getNameTriggerTime_of_day()
{
	return lang("Time_of_day")
}
getCategoryTriggerTime_of_day()
{
	return lang("Time")
}



DisableTriggerTime_of_day(ID)
{
	
	SetTimer,TriggerTime_of_dayLoop,off
	TriggerTime_of_dayCurrentTimes.remove(ID)
	
}

GenerateNameTriggerTime_of_day(ID)
{
	FormatTime,temptimestring,% GUISettingsOfElement%ID%time,HH:mm:ss ;find out the weekday of the new day
	if GUISettingsOfElement%ID%weekdays=1234567
		tempDaysstring:= lang("Every Day")
	else
	{
		IfInString,GUISettingsOfElement%ID%weekdays,2
			tempDaysstring.= lang("Mon (Short for Monday") ", "
		IfInString, GUISettingsOfElement%ID%weekdays,3
			tempDaysstring.= lang("Thu (Short for Thursday") ", "
		IfInString, GUISettingsOfElement%ID%weekdays,4
			tempDaysstring.=  lang("Wed (Short for Wednesday") ", "
		IfInString, GUISettingsOfElement%ID%weekdays,5
			tempDaysstring.= lang("Thu (Short for Thursday") ", "
		IfInString, GUISettingsOfElement%ID%weekdays,6
			tempDaysstring.= lang("Fri (Short for Friday") ", "
		IfInString, GUISettingsOfElement%ID%weekdays,7
			tempDaysstring.= lang("Sat (Short for Saturday") ", "
		IfInString, GUISettingsOfElement%ID%weekdays,1
			tempDaysstring.= lang("Sun (Short for Sunday")  ", "
		StringTrimRight,tempDaysstring,tempDaysstring,2
	}
	return lang("Time_of_day") " " temptimestring " " tempDaysstring
	
}
