iniAllConditions.="Flow_Enabled|" ;Add this condition to list of all conditions on initialisation

runConditionFlow_Enabled(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	tempFlowName:=%ElementID%flowName
	
	
	
	
	returnedWhetherFlowIsEnabled=
	ControlSetText,edit1,FlowIsEnabled?|%tempFlowName%|%FlowName%,CommandWindowOfManager 
	
	loop 20
	{
		if returnedWhetherFlowIsEnabled!=
			break
		sleep 10
	}
	if returnedWhetherFlowIsEnabled=enabled
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"yes")
	else if returnedWhetherFlowIsEnabled=disabled
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"no")
	else if returnedWhetherFlowIsEnabled=ǸoⱾuchȠaⱮe
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else 
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	
	
	
	

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
