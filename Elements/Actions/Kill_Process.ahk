iniAllActions.="Kill_Process|" ;Add this action to list of all actions on initialisation

RunActionKill_Process(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	Process,close, % v_replaceVariables(InstanceID,%ElementID%ProcessName) 
	
	
	if (ErrorLevel=0)
	{
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	}
	else
	{
		v_setVariable(InstanceID,"t_pid",ActionKill_ProcesstempPid)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
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