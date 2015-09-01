iniAllActions.="Execute_Flow|" ;Add this action to list of all actions on initialisation
TempConditionExecute_FlowData:=Object()

runActionExecute_Flow(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local tempFlowName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%flowName) 
	
	if tempFlowName=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Flow name not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Flow name")))
		return
	}
	
	TempConditionExecute_FlowData["FlowName"]:=tempFlowName
	TempConditionExecute_FlowData["ElementID"]:=ElementID
	TempConditionExecute_FlowData["InstanceID"]:=InstanceID
	TempConditionExecute_FlowData["ThreadID"]:=ThreadID
	TempConditionExecute_FlowData["ElementIDInInstance"]:=ElementIDInInstance
	
	returnedFlowStatus=
	
	local tempLocalVarsToSend
	if (%ElementID%SendLocalVars)
	{
		tempLocalVarsToSend:=Instance_%InstanceID%_LocalVariables.clone()
		;~ tempThreadVarsToSend:=Instance_%InstanceID%_Thread_%ThreadID%_Variables.clone() ;No Thread Variables
		
	}
	if (%ElementID%WaitToFinish)
	{
		if (%ElementID%ReturnVariables)
		{
			com_SendCommand({function: "ChangeFlowStatus", status: "Run", flowName: tempFlowName, localVariables: tempLocalVarsToSend, ThreadVariables: "",CallerElementID: ElementID, CallerInstanceID: InstanceID, CallerElementIDInInstance: ElementIDInInstance, CallerThreadID: ThreadID, WhetherToReturVariables: true },"manager") ;Send the command to the Manager.
		}
		else
		{
			com_SendCommand({function: "ChangeFlowStatus", status: "Run", flowName: tempFlowName, localVariables: tempLocalVarsToSend,ThreadVariables: tempThreadVarsToSend,CallerElementID: ElementID,CallerInstanceID: InstanceID, CallerElementIDInInstance: ElementIDInInstance, CallerThreadID: ThreadID},"manager") ;Send the command to the Manager.
		}
		
		
	}
	else
	{
		com_SendCommand({function: "ChangeFlowStatus", status: "Run", flowName: tempFlowName, localVariables: tempLocalVarsToSend,ThreadVariables: tempThreadVarsToSend,CallerElementID: ElementID},"manager") ;Send the command to the Manager.
	}
	
	TempConditionExecute_FlowData["Count"]:=0
	TempConditionExecute_FlowData["AnswerReceived"]:=false
	SetTimer, ConditionExecute_FlowTimerLabelLoop,50
	return
	
	ConditionExecute_FlowTimerLabelLoop:
	;~ ToolTip % TempConditionExecute_FlowData["Count"]
	TempConditionExecute_FlowData["Count"]+=1
	;~ ToolTip % strobj(returnedFlowStatus)
	if IsObject(returnedFlowStatus)
	{
		TempConditionExecute_FlowData["AnswerReceived"]:=true
		TempConditionExecute_FlowData["Count"]:=10000
		;~ MsgBox % TempConditionExecute_FlowData["AnswerReceived"]
	}
	
	
	if TempConditionExecute_FlowData["Count"]>100
	{
		SetTimer, ConditionExecute_FlowTimerLabelLoop,off
		runConditionExecute_FlowPart2(TempConditionExecute_FlowData["InstanceID"],TempConditionExecute_FlowData["ThreadID"],TempConditionExecute_FlowData["ElementID"],TempConditionExecute_FlowData["ElementIDInInstance"])
		;~ MsgBox fads
	}
	
	return
	
}

runConditionExecute_FlowPart2(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempFlowName:=TempConditionExecute_FlowData["FlowName"]
	;~ MsgBox % TempConditionExecute_FlowData["AnswerReceived"]
	if (TempConditionExecute_FlowData["AnswerReceived"]=true)
	{
		if (returnedFlowStatus["flowname"]!=tempFlowName)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected error! Manager reported the status of an other flow than requested." )
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		
		if (returnedFlowStatus["result"]="stopped")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Manager did not start the flow")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Manager did not start the flow"))
		}
		else if (returnedFlowStatus["result"]="disabled")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Flow " tempFlowName "could not be started. Flow is not enabled.")
			if (%ElementID%SkipDisabled)
			{
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
			}
			else
			{
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Flow %1% could not be started.",tempFlowName) " " lang("Flow is not enabled"))
			}
		}
		else if (returnedFlowStatus["result"]="NoSuchName")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! There is no flow named '" tempFlowName "'")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("There is no flow named '%1%'",tempFlowName))
			return
		}
		else if not (returnedFlowStatus["result"]="running")
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected Error! Manager reported an unknown status.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Unexpected Error!"))
			return
		}
		else ;Flow is running
		{
			if not (%ElementID%WaitToFinish)
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
			else
			{
				;It will wait now for a reply from the other flow. As soon as the reply arrived, this action will be marked as finished
				return
				
			}
		}
		
	}
	else 
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No response from the manager.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No response from the manager"))
		return
	}
	
	
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Edit", id: "flowName", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "SendLocalVars", default: 1, label: lang("Send local variables")})
	parametersToEdit.push({type: "Checkbox", id: "SkipDisabled", default: 0, label: lang("Skip disabled flows without error")})
	parametersToEdit.push({type: "Checkbox", id: "WaitToFinish", default: 0, label: lang("Wait for called flow to finish")})
	parametersToEdit.push({type: "Checkbox", id: "ReturnVariables", default: 0, label: lang("Return variables to the calling flow")})


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
