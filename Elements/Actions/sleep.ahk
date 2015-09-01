iniAllActions.="Sleep|" ;Add this action to list of all actions on initialisation

runActionSleep(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionSleepCurrentSleeps))
		ActionSleepCurrentSleeps:=Object()
	
	local tempDuration:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%duration)
	
	if %ElementID%Unit=1 ;Milliseconds
		tempActionSleepDuration:=tempDuration
	else if %ElementID%Unit=2 ;Seconds
		tempActionSleepDuration:=tempDuration * 1000
	else if %ElementID%Unit=3 ;minutes
		tempActionSleepDuration:=tempDuration * 60000
	
	ActionSleepCurrentSleeps.insert("Instance_" InstanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance,(A_TickCount + tempActionSleepDuration-10)) ;Save the end time.
	SetTimer,ActionSleepEnd,10
	
	return
	
	ActionSleepEnd:
	
	tempActionSleepFoundActiveSleep:=false
	for tempSleepid, tempSleepEndTime in ActionSleepCurrentSleeps ;loop through all sleepTimes and look whether the sleep time is over
	{
		;~ MsgBox %tempSleepid% - %tempSleepEndTime%
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
		
		tempActionSleepFoundActiveSleep:=true
	}
	if not (tempActionSleepFoundActiveSleep)
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label:  lang("Duration")})
	parametersToEdit.push({type: "edit", id: "Duration", default: 2, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes")]})

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