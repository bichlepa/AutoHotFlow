com_SendCommand(CommandObject,WhichCommandWindow,ToFlowName="")
{
	global flowName
	CommandObject["SendingFlow"]:=flowName
	
	
	commandstring:=strobj(CommandObject)
	;~ MsgBox %  "...-" strobj(CommandObject)
	
	ifinstring,WhichCommandWindow,editor
	{
		slot :=MailSlotAccessSlot("Flow" ToFlowName)
		if (slot!=-1)
			MailslotSend(slot, commandstring)
		else
			return 1
		;~ MsgBox command to %ToFlowName% `n%commandstring% 
		;~ ControlSetText,edit1,%commandstring% ,CommandWindowOfEditor,% "Ѻ" ToFlowName "Ѻ"
	}
	else
	{
		slot :=MailSlotAccessSlot("AutoHotFlowManager")
		if (slot!=-1)
			MailslotSend(slot, commandstring)
		else
			return 1
		;~ ControlSetText,edit1,%commandstring%,CommandWindowOfManager
	}
	return errorlevel
}

;Examples:

;   com_SendCommand({function: "FlowParametersChanged"},"editor",flowname) ;Send the command to the Editor.

;   com_SendCommand({function: "FlowParametersChanged"},"manager") ;Send the command to the Manager.