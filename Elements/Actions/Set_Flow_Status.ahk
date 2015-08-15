iniAllActions.="Set_Flow_Status|" ;Add this action to list of all actions on initialisation
TempConditionSet_Flow_StatusData:=Object()

runActionSet_Flow_Status(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName) 
	local tempstatustoset
	if tempFlowName=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Flow name not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Flow name")))
		return
	}
	
	TempConditionSet_Flow_StatusData["FlowName"]:=tempFlowName
	TempConditionSet_Flow_StatusData["ElementID"]:=ElementID
	TempConditionSet_Flow_StatusData["InstanceID"]:=InstanceID
	TempConditionSet_Flow_StatusData["ThreadID"]:=ThreadID
	TempConditionSet_Flow_StatusData["ElementIDInInstance"]:=ElementIDInInstance
	TempConditionSet_Flow_StatusData["statusToSet"]:=%ElementID%Enable
	
	returnedFlowStatus=
	
	if (TempConditionSet_Flow_StatusData["statusToSet"]=1)
		tempstatustoset:="enable"
	else
		tempstatustoset:="disable"
	
	com_SendCommand({function: "ChangeFlowStatus", status: tempstatustoset, flowName: tempFlowName,CallerElementID: ElementID},"manager") ;Send the command to the Manager.
	
	
	TempConditionSet_Flow_StatusData["Count"]:=0
	TempConditionSet_Flow_StatusData["AnswerReceived"]:=false
	SetTimer, ConditionSet_Flow_StatusTimerLabelLoop,50
	return
	
	ConditionSet_Flow_StatusTimerLabelLoop:
	;~ ToolTip % TempConditionSet_Flow_StatusData["Count"]
	TempConditionSet_Flow_StatusData["Count"]+=1
	;~ ToolTip % strobj(returnedFlowStatus)
	if IsObject(returnedFlowStatus)
	{
		TempConditionSet_Flow_StatusData["AnswerReceived"]:=true
		TempConditionSet_Flow_StatusData["Count"]:=10000
		;~ MsgBox % TempConditionSet_Flow_StatusData["AnswerReceived"]
	}
	
	
	if TempConditionSet_Flow_StatusData["Count"]>100
	{
		SetTimer, ConditionSet_Flow_StatusTimerLabelLoop,off
		runConditionSet_Flow_StatusPart2(TempConditionSet_Flow_StatusData["InstanceID"],TempConditionSet_Flow_StatusData["ThreadID"],TempConditionSet_Flow_StatusData["ElementID"],TempConditionSet_Flow_StatusData["ElementIDInInstance"])
		;~ MsgBox fads
	}
	
	return
	
}

runConditionSet_Flow_StatusPart2(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=TempConditionSet_Flow_StatusData["FlowName"]
	;~ MsgBox % TempConditionSet_Flow_StatusData["AnswerReceived"]
	if (TempConditionSet_Flow_StatusData["AnswerReceived"]=true)
	{
		if (returnedFlowStatus["flowname"]!=tempFlowName)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected error! Manager reported the status of an other flow than requested." )
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		
		if (returnedFlowStatus["result"]="NoSuchName")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! There is no flow named '" tempFlowName "'")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("There is no flow named '%1%'",tempFlowName))
			return
		}
		else if (returnedFlowStatus["result"]="enabled")
		{
			if (TempConditionSet_Flow_StatusData["statusToSet"]=1)
			{
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
				
			}
			else
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Manager did not enable the flow")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Manager did not enable the flow"))
				
			}
			
		}
		else if (returnedFlowStatus["result"]="disabled")
		{
			if (TempConditionSet_Flow_StatusData["statusToSet"]=1)
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Manager did not disable the flow")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Manager did not disable the flow"))
			}
			else
			{
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
			}
			
			
		}
		else ;Flow is stopped
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
	
	parametersToEdit:=["Label|" lang("Flow_name"),"Text||flowName","Label|" lang("New state"),"Radio|1|Enable|" lang("Enable") ";" lang("Disable")]
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
