com_SendCommand(CommandObject,FlowName="")
{
	global
	commandstring:=strobj(CommandObject)
	;~ MsgBox %FlowName%`n%commandstring%
	ControlSetText,edit1,%commandstring% ,CommandWindowOfEditor,% "Ѻ" FlowName "Ѻ§" HiddenGUIHWND "§"
	
	return errorlevel
}

;Example:
;   com_SendCommand({function: "FlowParametersChanged"},%tempselectedID%name) ;Send the command to the Editor.


;com_SendCommand({function: "AnswerFlowStatus", result: "NoSuchName", flowName: tempNewReceivedCommand["flowname"]},tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.

