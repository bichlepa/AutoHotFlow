com_SendCommand(CommandObject,WhichCommandWindow,ToFlowName="")
{
	global flowSettings
	global CurrentManagerHiddenWindowID
	CommandObject["SendingFlow"]:=flowSettings.Name
	commandstring:=strobj(CommandObject)
	;~ MsgBox %  "...-" strobj(CommandObject)
	
	ifinstring,WhichCommandWindow,editor
	{
		;~ MsgBox command to %ToFlowName% `n%commandstring% 
		ControlSetText,edit1,%commandstring% ,CommandWindowOfEditor,% "Ѻ" ToFlowName "Ѻ§" CurrentManagerHiddenWindowID "§"
	}
	else ifinstring,WhichCommandWindow,custom
	{
		ControlSetText,edit1,%commandstring%,%ToFlowName%
	}
	else
	{
		ControlSetText,edit1,%commandstring%,CommandWindowOfManager,% "§" CurrentManagerHiddenWindowID "§"
	}
	return errorlevel
}

;Examples:

;   com_SendCommand({function: "FlowParametersChanged"},"editor",anyflowname) ;Send the command to the Editor.

;   com_SendCommand({function: "FlowParametersChanged"},"manager") ;Send the command to the Manager.