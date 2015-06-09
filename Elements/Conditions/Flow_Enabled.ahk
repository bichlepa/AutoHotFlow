iniAllConditions.="Flow_Enabled|" ;Add this condition to list of all conditions on initialisation

runConditionFlow_Enabled(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName) 
	
	
	
	
	returnedWhetherFlowIsEnabled=
	ControlSetText,edit1,FlowIsEnabled?|%tempFlowName%|%FlowName%,CommandWindowOfManager 
	
	loop 20
	{
		if returnedWhetherFlowIsEnabled!=
			break
		sleep 10
	}
	if returnedWhetherFlowIsEnabled=enabled
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	else if returnedWhetherFlowIsEnabled=disabled
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
	else if returnedWhetherFlowIsEnabled=ǸoⱾuchȠaⱮe
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	
	
	
	

	return
}
getNameConditionFlow_Enabled()
{
	return lang("Flow_enabled")
}
getCategoryConditionFlow_Enabled()
{
	return lang("Flow_control")
}

getParametersConditionFlow_Enabled()
{
	global
	
	parametersToEdit:=["Label|" lang("Flow_name"),"Text||flowName"]
	return parametersToEdit
}

GenerateNameConditionFlow_Enabled(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return % lang("Flow_enabled") "`n"  GUISettingsOfElement%ID%flowName
	
	
}

CheckSettingsConditionFlow_Enabled(ID)
{
	
	
}
