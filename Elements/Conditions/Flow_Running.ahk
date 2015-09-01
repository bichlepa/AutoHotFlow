iniAllConditions.="Flow_Running|" ;Add this condition to list of all conditions on initialisation
TempConditionFlow_RunningData:=Object()

runConditionFlow_Running(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName)
	
	if tempFlowName=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Flow name not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Flow name")))
		return
	}
	
	TempConditionFlow_RunningData["FlowName"]:=tempFlowName
	TempConditionFlow_RunningData["ElementID"]:=ElementID
	TempConditionFlow_RunningData["InstanceID"]:=InstanceID
	TempConditionFlow_RunningData["ThreadID"]:=ThreadID
	TempConditionFlow_RunningData["ElementIDInInstance"]:=ElementIDInInstance
	
	returnedFlowStatus=
	com_SendCommand({function: "AskFlowStatus", status: "running", flowName: tempFlowName},"manager") ;Send the command to the Manager.
	
	TempConditionFlow_RunningData["Count"]:=0
	TempConditionFlow_RunningData["AnswerReceived"]:=false
	SetTimer, ConditionFlow_RunningTimerLabelLoop,20
	
	return
	
	ConditionFlow_RunningTimerLabelLoop:
	;~ ToolTip % TempConditionFlow_RunningData["Count"]
	TempConditionFlow_RunningData["Count"]+=1
	;~ ToolTip % strobj(returnedFlowStatus)
	if IsObject(returnedFlowStatus)
	{
		TempConditionFlow_RunningData["AnswerReceived"]:=true
		TempConditionFlow_RunningData["Count"]:=100
		;~ MsgBox % TempConditionFlow_RunningData["AnswerReceived"]
	}
	
	
	if TempConditionFlow_RunningData["Count"]>20
	{
		SetTimer, ConditionFlow_RunningTimerLabelLoop,off
		runConditionFlow_RunningPart2(TempConditionFlow_RunningData["InstanceID"],TempConditionFlow_RunningData["ThreadID"],TempConditionFlow_RunningData["ElementID"],TempConditionFlow_RunningData["ElementIDInInstance"])
		;~ MsgBox fads
	}
	
	return
	

}

runConditionFlow_RunningPart2(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=TempConditionFlow_RunningData["FlowName"]
	;~ MsgBox % TempConditionFlow_RunningData["AnswerReceived"]
	if (TempConditionFlow_RunningData["AnswerReceived"]=true)
	{
		if (returnedFlowStatus["flowname"]!=tempFlowName)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected error! Manager reported the status of an other flow than requested." )
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		
		if (returnedFlowStatus["result"]="running")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		else if (returnedFlowStatus["result"]="stopped")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
		else if (returnedFlowStatus["result"]="NoSuchName")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! There is no flow named '" tempFlowName "'")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("There is no flow named '%1%'",tempFlowName))
			return
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected Error! Manager reported an unknown status.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
	}
	else 
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No response from the manager.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No response from the manager"))
		return
	}
	
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Edit", id: "flowName", content: "String", WarnIfEmpty: true})

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
