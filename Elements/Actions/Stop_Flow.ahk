iniAllActions.="Stop_Flow|" ;Add this action to list of all actions on initialisation

runActionStop_Flow(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	tempFlowName:=%ElementID%flowName
	
	
	
	
	returnedFlowIsStopped=
	ControlSetText,edit1,StopFlow|%tempFlowName%|%FlowName%,CommandWindowOfManager 
	
	loop 10 ;Enabling flow may take a long time
	{
		if returnedFlowIsStopped!=
			break
		sleep 100
	}
	if returnedFlowIsStopped=
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else if returnedFlowIsStopped=ǸoⱾuchȠaⱮe
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	
	
	
	

	return
}
getNameActionStop_Flow()
{
	return lang("Stop_flow")
}
getCategoryActionStop_Flow()
{
	return lang("Flow_control")
}

getParametersActionStop_Flow()
{
	global
	
	parametersToEdit:=["Label|" lang("Flow_name"),"Text||flowName"]
	return parametersToEdit
}

GenerateNameActionStop_Flow(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return % lang("Stop_flow") "`n"  GUISettingsOfElement%ID%flowName
	
	
}

CheckSettingsActionStop_Flow(ID)
{
	
}
