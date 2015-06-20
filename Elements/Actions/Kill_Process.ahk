iniAllActions.="Kill_Process|" ;Add this action to list of all actions on initialisation

RunActionKill_Process(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	Process,close, % v_replaceVariables(InstanceID,ThreadID,%ElementID%ProcessName) 
	
	
	if (ErrorLevel=0)
	{
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
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