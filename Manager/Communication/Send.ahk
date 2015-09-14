com_SendCommand(CommandObject,WhichCommandWindow,ToFlowName="")
{
	global
	commandstring:=strobj(CommandObject)
	
	ifinstring,WhichCommandWindow,editor
	{
		;~ MsgBox command to %ToFlowName% `n%commandstring% 
		ControlSetText,edit1,%commandstring% ,CommandWindowOfEditor,% "Ѻ" ToFlowName "Ѻ§" HiddenGUIHWND "§"
	}
	else ifinstring,WhichCommandWindow,manager
	{
		ControlSetText,edit1,%commandstring%,CommandWindowOfManager,% "§" ToFlowName "§" ;Toflowname contains the hidden gui hwnd of manager
	}
	else
	{
		if not a_iscompiled
			MsgBox Error! Should send message to unknown receiver: %WhichCommandWindow%
		
	}
	return errorlevel
}

;Example:
;   com_SendCommand({function: "FlowParametersChanged"},"editor",%tempselectedID%name) ;Send the command to the Editor.


;com_SendCommand({function: "AnswerFlowStatus", result: "NoSuchName", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.

