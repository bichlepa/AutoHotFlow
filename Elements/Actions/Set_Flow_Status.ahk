iniAllActions.="Set_Flow_Status|" ;Add this action to list of all actions on initialisation

runActionSet_Flow_Status(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	tempFlowName:=%ElementID%flowName
	
	
	
	if (%ElementID%Enable=1)
	{
		returnedFlowIsEnabled=
		ControlSetText,edit1,EnableFlow|%tempFlowName%|%FlowName%,CommandWindowOfManager 
		
		loop 200 ;Enabling flow may take a long time
		{
			if returnedFlowIsEnabled!=
				break
			sleep 100
		}
		if returnedFlowIsEnabled=
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		else if returnedFlowIsEnabled=ǸoⱾuchȠaⱮe
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
		
	}
	else
	{
		returnedFlowIsDisabled=
		ControlSetText,edit1,DisableFlow|%tempFlowName%|%FlowName%,CommandWindowOfManager 
		
		loop 100
		{
			if returnedFlowIsDisabled!=
				break
			sleep 50
		}
		if returnedFlowIsDisabled=
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		else if returnedFlowIsDisabled=ǸoⱾuchȠaⱮe
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
		
	}
	
	
	

	return
}
getNameActionSet_Flow_Status()
{
	return lang("Set_flow_status")
}
getCategoryActionSet_Flow_Status()
{
	return lang("Flow_control")
}

getParametersActionSet_Flow_Status()
{
	global
	
	parametersToEdit:=["Label|" lang("Flow_name"),"Text||flowName","Radio|1|Enable|" lang("Enable") ";" lang("Disable")]
	return parametersToEdit
}

GenerateNameActionSet_Flow_Status(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return % lang("Set_flow_status") "`n"  GUISettingsOfElement%ID%flowName
	
	
}

CheckSettingsActionSet_Flow_Status(ID)
{
	
	
}
