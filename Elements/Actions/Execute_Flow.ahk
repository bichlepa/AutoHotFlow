iniAllActions.="Execute_Flow|" ;Add this action to list of all actions on initialisation

runActionExecute_Flow(InstanceID,ElementID,ElementIDInInstance)
{
	global
	returnedFlowIsRunning=
	tempFlowName:=%ElementID%flowName
	tempVarsToSend=
	if (%ElementID%SendLocalVars)
	{
		tempVarsToSend:=v_WriteLocalVariablesToString("Instance_" InstanceID)
	}
	if (%ElementID%WaitToFinish)
	{
		if (%ElementID%ReturnVariables)
			ControlSetText,edit1,ExecuteFlow|%tempFlowName%|%FlowName%|%tempVarsToSend%|%InstanceID%|%ElementIDInInstance%|ReturnVariables,CommandWindowOfManager 
		else
			ControlSetText,edit1,ExecuteFlow|%tempFlowName%|%FlowName%|%tempVarsToSend%|%InstanceID%|%ElementIDInInstance%,CommandWindowOfManager 
		
		
	}
	else
		ControlSetText,edit1,ExecuteFlow|%tempFlowName%|%FlowName%|%tempVarsToSend%|,CommandWindowOfManager 
	loop 20
	{
		if returnedFlowIsRunning!=
			break
		sleep 10
	}
		;MsgBox ga %returnedFlowIsRunning%
	if returnedFlowIsRunning=ǸoⱾuchȠaⱮe
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else if returnedFlowIsRunning=Dἰsḁbled
	{
		if (%ElementID%SkipDisabled)
			MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	}
	else if returnedFlowIsRunning=
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else ;if the flow is running
	{
		if (%ElementID%WaitToFinish)
		{
			loop  ;Wait until finished
			{
				if returnedFlowHasFinished_Instance_%InstanceID%_Element_%ElementIDInInstance%!=
					break
				sleep 10
			}
			if (%ElementID%ReturnVariables)
			{
				loop, parse, returnedFlowHasFinishedVariables_Instance_%InstanceID%_Element_%ElementIDInInstance%,◘
				{
					
					StringGetPos,temppos,A_LoopField,=
					if temppos!=
					{
						stringleft,tempVarName,A_LoopField,% temppos
						StringTrimLeft,tempVarContent,A_LoopField,% temppos+1
						;MsgBox %A_LoopField% %tempVarName% %tempVarContent%
						v_setVariable(InstanceID,tempVarName,tempVarContent)
						
					}
					
				}
			}
		}
		
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal") 
		
	}
	

	return
}
getNameActionExecute_Flow()
{
	return lang("Execute_flow")
}
getCategoryActionExecute_Flow()
{
	return lang("Flow_control")
}

getParametersActionExecute_Flow()
{
	global
	
	parametersToEdit:=["Label|" lang("Flow_name"),"Text||flowName","Label| " lang("Options"),"Checkbox|1|SendLocalVars|" lang("Send local variables"),"Checkbox|0|SkipDisabled|" lang("Skip disabled flows without error"),"Checkbox|0|WaitToFinish|" lang("Wait for called flow to finish"),"Checkbox|0|ReturnVariables|" lang("Return variables to the calling flow")]
	return parametersToEdit
}

GenerateNameActionExecute_Flow(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return % lang("Execute_flow") "`n" GUISettingsOfElement%ID%flowName
	
	
}

CheckSettingsActionExecute_Flow(ID)
{
	
	temp:=GUISettingsOfElement%ID%WaitToFinish
	
	GuiControl,Enable%temp%,GUISettingsOfElement%ID%ReturnVariables ;Deactivate this option when we are not waiting
	if !(GUISettingsOfElement%ID%WaitToFinish)
	{
		GuiControl,,GUISettingsOfElement%ID%ReturnVariables,0 
	}
}
