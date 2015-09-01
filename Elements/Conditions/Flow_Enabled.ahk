iniAllConditions.="Flow_Enabled|" ;Add this condition to list of all conditions on initialisation
TempConditionFlow_EnabledData:=Object()

runConditionFlow_Enabled(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName)
	
	if tempFlowName=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Flow name not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Flow name")))
		return
	}
	
	TempConditionFlow_EnabledData["FlowName"]:=tempFlowName
	TempConditionFlow_EnabledData["ElementID"]:=ElementID
	TempConditionFlow_EnabledData["InstanceID"]:=InstanceID
	TempConditionFlow_EnabledData["ThreadID"]:=ThreadID
	TempConditionFlow_EnabledData["ElementIDInInstance"]:=ElementIDInInstance
	
	returnedFlowStatus=
	com_SendCommand({function: "AskFlowStatus", status: "Enabled", flowName: tempFlowName},"manager") ;Send the command to the Manager.
	
	TempConditionFlow_EnabledData["Count"]:=0
	TempConditionFlow_RunningData["AnswerReceived"]:=false
	SetTimer, ConditionFlow_EnabledTimerLabelLoop,20
	
	return
	
	ConditionFlow_EnabledTimerLabelLoop:
	;~ ToolTip % TempConditionFlow_EnabledData["Count"]
	TempConditionFlow_EnabledData["Count"]+=1
	;~ ToolTip % strobj(returnedFlowStatus)
	if IsObject(returnedFlowStatus)
	{
		TempConditionFlow_EnabledData["AnswerReceived"]:=true
		TempConditionFlow_EnabledData["Count"]:=100
		;~ MsgBox % TempConditionFlow_EnabledData["AnswerReceived"]
	}
	
	
	if TempConditionFlow_EnabledData["Count"]>20
	{
		SetTimer, ConditionFlow_EnabledTimerLabelLoop,off
		runConditionFlow_EnabledPart2(TempConditionFlow_EnabledData["InstanceID"],TempConditionFlow_EnabledData["ThreadID"],TempConditionFlow_EnabledData["ElementID"],TempConditionFlow_EnabledData["ElementIDInInstance"])
		;~ MsgBox fads
	}
	
	return
}

runConditionFlow_EnabledPart2(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=TempConditionFlow_EnabledData["FlowName"]
	;~ MsgBox % TempConditionFlow_EnabledData["AnswerReceived"]
	if (TempConditionFlow_EnabledData["AnswerReceived"]=true)
	{
		if (returnedFlowStatus["flowname"]!=tempFlowName)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected error! Manager reported the status of an other flow than requested." )
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		
		if (returnedFlowStatus["result"]="Enabled")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
		else if (returnedFlowStatus["result"]="disabled")
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Edit", id: "flowName", content: "String", WarnIfEmpty: true})

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
