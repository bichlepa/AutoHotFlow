iniAllActions.="Kill_Process|" ;Add this action to list of all actions on initialisation

RunActionKill_Process(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempProcessName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ProcessName) 
	
	Process,close, % tempProcessName
	
	
	if (ErrorLevel=0)
	{
		Process,exist,% tempProcessName
		if (ErrorLevel=0)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Seeked process does not exist")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Seeked process does not exist"))
			
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Process could not be closed")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Process could not be closed"))
			
		}

		return
	}
	else
	{
		v_setVariable(InstanceID,ThreadID,"a_pid",ActionKill_ProcesstempPid,,true)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	return
}
getNameActionKill_Process()
{
	return lang("Kill_Process")
}
getCategoryActionKill_Process()
{
	return lang("Process")
}

getParametersActionKill_Process()
{
	global
	
	parametersToEdit:=["Label|" lang("Process name or ID"),"Text||ProcessName"]
	return parametersToEdit
}

GenerateNameActionKill_Process(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Kill_Process") ": "  GUISettingsOfElement%ID%ProcessName
	
}