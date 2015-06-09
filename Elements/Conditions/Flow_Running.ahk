iniAllConditions.="Flow_Running|" ;Add this condition to list of all conditions on initialisation

runConditionFlow_Running(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName)
	
	
	
	
	returnedWhetherFlowIsRunning=
	ControlSetText,edit1,FlowIsRunning?|%tempFlowName%|%FlowName%,CommandWindowOfManager 
	
	loop 20
	{
		if returnedWhetherFlowIsRunning!=
			break
		sleep 10
	}
	if returnedWhetherFlowIsRunning=running
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	else if returnedWhetherFlowIsRunning=stopped
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
	else if returnedWhetherFlowIsRunning=ǸoⱾuchȠaⱮe
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	
	
	
	

	return
}
getNameConditionFlow_Running()
{
	return lang("Flow_running")
}
getCategoryConditionFlow_Running()
{
	return lang("Flow_control")
}

getParametersConditionFlow_Running()
{
	global
	
	parametersToEdit:=["Label|" lang("Flow_name"),"Text||flowName"]
	return parametersToEdit
}

GenerateNameConditionFlow_Running(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return % lang("Flow_running") "`n"  GUISettingsOfElement%ID%flowName
	
	
}

CheckSettingsConditionFlow_Running(ID)
{
	
	
}
