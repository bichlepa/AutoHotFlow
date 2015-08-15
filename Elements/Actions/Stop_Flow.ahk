iniAllActions.="Stop_Flow|" ;Add this action to list of all actions on initialisation
TempConditionStop_FlowData:=Object()

runActionStop_Flow(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName) 
	
	if tempFlowName=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Flow name not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Flow name")))
		return
	}
	
	TempConditionStop_FlowData["FlowName"]:=tempFlowName
	TempConditionStop_FlowData["ElementID"]:=ElementID
	TempConditionStop_FlowData["InstanceID"]:=InstanceID
	TempConditionStop_FlowData["ThreadID"]:=ThreadID
	TempConditionStop_FlowData["ElementIDInInstance"]:=ElementIDInInstance
	
	returnedFlowStatus=
	
	
	com_SendCommand({function: "ChangeFlowStatus", status: "Stop", flowName: tempFlowName,CallerElementID: ElementID},"manager") ;Send the command to the Manager.
	
	
	TempConditionStop_FlowData["Count"]:=0
	TempConditionStop_FlowData["AnswerReceived"]:=false
	SetTimer, ConditionStop_FlowTimerLabelLoop,50
	return
	
	ConditionStop_FlowTimerLabelLoop:
	;~ ToolTip % TempConditionStop_FlowData["Count"]
	TempConditionStop_FlowData["Count"]+=1
	;~ ToolTip % strobj(returnedFlowStatus)
	if IsObject(returnedFlowStatus)
	{
		TempConditionStop_FlowData["AnswerReceived"]:=true
		TempConditionStop_FlowData["Count"]:=10000
		;~ MsgBox % TempConditionStop_FlowData["AnswerReceived"]
	}
	
	
	if TempConditionStop_FlowData["Count"]>20
	{
		SetTimer, ConditionStop_FlowTimerLabelLoop,off
		runConditionStop_FlowPart2(TempConditionStop_FlowData["InstanceID"],TempConditionStop_FlowData["ThreadID"],TempConditionStop_FlowData["ElementID"],TempConditionStop_FlowData["ElementIDInInstance"])
		;~ MsgBox fads
	}
	
	return
	
}

runConditionStop_FlowPart2(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=TempConditionStop_FlowData["FlowName"]
	;~ MsgBox % TempConditionStop_FlowData["AnswerReceived"]
	if (TempConditionStop_FlowData["AnswerReceived"]=true)
	{
		if (returnedFlowStatus["flowname"]!=tempFlowName)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected error! Manager reported the status of an other flow than requested." )
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		
		if (returnedFlowStatus["result"]="running")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Manager did not stop the flow")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Manager did not stop the flow"))
		}
		else if (returnedFlowStatus["result"]="NoSuchName")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! There is no flow named '" tempFlowName "'")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("There is no flow named '%1%'",tempFlowName))
			return
		}
		else if not (returnedFlowStatus["result"]="stopped")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected Error! Manager reported an unknown status.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		else ;Flow is stopped
		{
			
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
			
		}
		
	}
	else 
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No response from the manager.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No response from the manager"))
		return
	}
	
	
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
