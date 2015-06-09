iniAllActions.="Set_process_priority|" ;Add this action to list of all actions on initialisation

RunActionSet_process_priority(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempname
	temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Priority) 
	tempname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ProcessName) 
	if temp=1
		Process,Priority, % tempname,L
	else if temp=2
		Process,Priority, % tempname,B
	else if temp=3
		Process,Priority, % tempname,N
	else if temp=4
		Process,Priority, % tempname,A
	else if temp=5
		Process,Priority, % tempname,H
	else if temp=6
		Process,Priority, % tempname,R
	
	
	if (ErrorLevel=0)
	{
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	}
	else
	{
		v_setVariable(InstanceID,ThreadID,t_pid,ActionSet_process_prioritytempPid)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	return
}
getNameActionSet_process_priority()
{
	return lang("Set_process_priority")
}
getCategoryActionSet_process_priority()
{
	return lang("Process")
}

getParametersActionSet_process_priority()
{
	global
	
	parametersToEdit:=["Label|" lang("Process name or ID"),"Text||ProcessName","Label| " lang("Priority"),"Radio|3|Priority|" lang("Low") ";" lang("Below normal") ";" lang("Normal") ";" lang("Above normal") ";" lang("High") ";" lang("Realtime")]
	return parametersToEdit
}

GenerateNameActionSet_process_priority(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Set_process_priority") ": "  GUISettingsOfElement%ID%ProcessName
	
}