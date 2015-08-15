iniAllTriggers.="Time_of_day|" ;Add this trigger to list of all triggers on initialisation

TriggerTime_of_dayCurrentTimes:=Object()

EnableTriggerTime_of_day(ElementID)
{
	global
	
	local tempTriggerParams:=Object()
	tempTriggerParams["TimeStamp"]:=%ElementID%time
	tempTriggerParams["ElementID"]:=ElementID

	
	if (%ElementID%WeekDays="") ;If at least one day is selected
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! No weekdays selected")
		MsgBox,16,% lang("Error"),% lang("The hotkey %1% cannot be set!",temphotkey) " " lang("No weekdays selected")
		return
	}
	
	;Find the next timestamp, where the trigger should start
	FormatTime,TriggerTime_of_dayNewTimeWithoutDate,% tempTriggerParams["TimeStamp"],HHmmss
	;~ MsgBox % "sdafklj---" TriggerTime_of_dayNewTimeWithoutDate
	loop 8 ;Go through all days of week
	{
		
		TriggerTime_of_dayNewTime:=A_YYYY . A_MM . A_DD . TriggerTime_of_dayNewTimeWithoutDate ;Create a new time and date
		;~ MsgBox %TriggerTime_of_dayNewTime%    %TriggerTime_of_dayNewTimeWithoutDate%
		EnvAdd,TriggerTime_of_dayNewTime,% A_Index -1,days
		;~ MsgBox %TriggerTime_of_dayNewTime%    %TriggerTime_of_dayNewTimeWithoutDate%
		tempdiff:=TriggerTime_of_dayNewTime
		EnvSub,tempdiff,a_now,seconds
		if (tempdiff>0 ) ;Prove that the time is not passed yet. This may occure in the first loop
		{
			FormatTime,tempDayOfWeek,%TriggerTime_of_dayNewTime%,WDay ;find out the weekday of the new day
			;~ MsgBox % tempDayOfWeek "   " %ElementID%WeekDays "    " TriggerTime_of_dayNewTime
			IfInString,%ElementID%WeekDays,% tempDayOfWeek
			{
				tempTriggerParams["TimeStamp"]:=TriggerTime_of_dayNewTime ;Add the new time and date as the next trigger time
				
				break
			}
			
			
		}
	}
	
	
	
	TriggerTime_of_dayCurrentTimes.push(tempTriggerParams) 
	SetTimer,TriggerTime_of_dayLoop,1000
	
	return
	
	TriggerTime_of_dayLoop:
	
	
	for temp_index, tempTime_of_dayObject in TriggerTime_of_dayCurrentTimes ;loop through all sleepTimes and look whether the sleep time is over
	{
		tempTime_of_dayEndTime:=tempTime_of_dayObject["TimeStamp"]
		tempTime_of_dayid:=tempTime_of_dayObject["ElementID"]
		;~ MsgBox % tempTime_of_dayEndTime "`n" strobj(TriggerTime_of_dayCurrentTimes)
		tempTime_of_dayDiffTime:=tempTime_of_dayEndTime
		EnvSub,tempTime_of_dayDiffTime,a_now,seconds
		
		if (tempTime_of_dayDiffTime<=0) ;If the time is over
		{
			
			if (tempTime_of_dayDiffTime>-60) ;If less than 60 seconds passed after the triggertime
			{
				r_Trigger(tempTime_of_dayid )
			}
			
			if (%tempTime_of_dayid%WeekDays!="") ;Set a new time
			{
				
				FormatTime,TriggerTime_of_dayNewTimeWithoutDate,%tempTime_of_dayEndTime%,HHmmss
				;~ MsgBox % "sdafklj---" TriggerTime_of_dayNewTimeWithoutDate
				loop 8 ;Go through all days of week
				{
					
					TriggerTime_of_dayNewTime:=A_YYYY . A_MM . A_DD . TriggerTime_of_dayNewTimeWithoutDate ;Create a new time and date
					EnvAdd,TriggerTime_of_dayNewTime,% A_Index -1,days
					;MsgBox %TriggerTime_of_dayNewTime%    %TriggerTime_of_dayNewTimeWithoutDate%
					tempdiff:=TriggerTime_of_dayNewTime
					EnvSub,tempdiff,a_now,seconds
					if (tempdiff>0 ) ;Prove that the time is not passed yet. This may occure in the first loop
					{
						FormatTime,tempDayOfWeek,%TriggerTime_of_dayNewTime%,WDay ;find out the weekday of the new day
						;MsgBox % tempDayOfWeek "   " %tempTime_of_dayid%WeekDays
						IfInString,%tempTime_of_dayid%WeekDays,%tempDayOfWeek%
						{
							TriggerTime_of_dayCurrentTimes[temp_index]["TimeStamp"]:=TriggerTime_of_dayNewTime ;Add the new time and date as the next trigger time
							
							break
						}
						
						
					}
				}
				
				
			}
			
			
		}
		
	}
	if not (TriggerTime_of_dayCurrentTimes.HasKey(1))
		settimer,TriggerTime_of_dayLoop,off
	
	
	;MsgBox % nextTimerRun

	return
	
	
	
}

DisableTriggerTime_of_day(ID)
{
	
	
	
	for tempTime_of_dayid, tempTime_of_dayObject in TriggerTime_of_dayCurrentTimes
	{
		if (tempTime_of_dayObject["elementid"]=ID)
		{
			
			TriggerTime_of_dayCurrentTimes.delete(tempTime_of_dayid)
		}
		
	}
	
	
	
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
			tempDaysstring.= lang("Tue (Short for Tuesday") ", "
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
