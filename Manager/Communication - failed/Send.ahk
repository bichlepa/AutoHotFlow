com_SendCommand(CommandObject,ToFlowName="")
{
	commandstring:=strobj(CommandObject)
	;~ MsgBox %FlowName%`n%commandstring%
	if (MailSlotAccessSlot("Flow" ToFlowName)!=-1)
			MailslotSend(MailSlotAccessSlot("Flow" ToFlowName), commandstring)
		else
			return 1
	;~ ControlSetText,edit1,%commandstring% ,CommandWindowOfEditor,% "Ѻ" ToFlowName "Ѻ"
	
	return errorlevel
}

;Example:
;   com_SendCommand({function: "FlowParametersChanged"},%tempselectedID%name) ;Send the command to the Editor.


;com_SendCommand({function: "AnswerFlowStatus", result: "NoSuchName", flowName: tempNewReceivedCommand["flowname"]},tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.

