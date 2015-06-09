iniAllConditions.="Process_is_running|" ;Add this condition to list of all conditions on initialisation

runConditionProcess_is_running(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	
	;MsgBox % %ElementID%ProcessName
	Process,exist,% v_replaceVariables(InstanceID,ThreadID,%ElementID%ProcessName) 
	if errorlevel
	{
		v_setVariable(InstanceID,ThreadID,t_pid,errorlevel)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
	
	

	return
}
getNameConditionProcess_is_running()
{
	return lang("Process_is_running")
}
getCategoryConditionProcess_is_running()
{
	return lang("Process")
}

getParametersConditionProcess_is_running()
{
	global
	
	parametersToEdit:=["Label|" lang("Process name"),"Text||ProcessName"]
	return parametersToEdit
}

GenerateNameConditionProcess_is_running(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return % lang("Process_is_running") " "  GUISettingsOfElement%ID%ProcessName
	
	
}
