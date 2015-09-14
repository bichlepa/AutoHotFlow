goto,jumpovercommunicationlabels

;Create a hidden window to allow other triggers or manager to send messages 
com_CreateHiddenReceiverWindow()
{
	global
	gui,45:default
	gui,new,,CommandWindowOfManager
	gui,45:+HwndHiddenGUIHWND
	gui,add,text,,§%HiddenGUIHWND%§
	gui,add,edit,vCommandWindowRecieve gCommandWindowRecieve
	
	iniwrite,%HiddenGUIHWND%,settings.ini,common,Hidden window ID of manager
	;~ gui,show ;Only for debugging
	
}


;React on commands from manager, generated scripts or other flows
CommandWindowRecieve:
gui,submit,NoHide
CommandCount++
ReceivedCommandsBuffer=%CommandWindowRecieve%█▬►
logger("a3","Command window received command: " CommandWindowRecieve)
SetTimer,EvaluateCommand,-1
return

EvaluateCommand:
Loop
{
	StringGetPos,tempCommandLength,ReceivedCommandsBuffer,█▬►
	if (errorlevel)
		break
	
	StringLeft,tempCommand,ReceivedCommandsBuffer,tempCommandLength
	StringTrimLeft,ReceivedCommandsBuffer,ReceivedCommandsBuffer,tempCommandLength+3
	
	
	;Read command and fill an object with informations
	tempNewReceivedCommand:=strobj(tempCommand)
	;~ MsgBox % tempCommand
	
	;Evaluating command
	
	if (tempNewReceivedCommand["Function"]="ShowManagerWindow")
	{
		logger("a2","Command received. Manager window should be shown")
		gosub ShowMainGUI
	}
	else if (tempNewReceivedCommand["Function"]="ReportStatus")
	{
		
		logger("a2","Command received. Flow " tempNewReceivedCommand["SendingFlow"] " reports its status: "  tempNewReceivedCommand["status"])
		
		tempid:=IDOfName(tempNewReceivedCommand["SendingFlow"],"Flow")
		if (tempNewReceivedCommand["status"]="stopped")
		{
			%tempid%running=false
			if (IDOF(tempSelectedID)=IDOF(tempid))
				guicontrol,,ButtonRunFlow,% lang("Run")
		}
		else if (tempNewReceivedCommand["status"]="running")
		{
			%tempid%running=true
			if (IDOF(tempSelectedID)=IDOF(tempid))
				guicontrol,,ButtonRunFlow,% lang("Stop")
		}
		else if (tempNewReceivedCommand["status"]="stopping")
		{
			%tempid%running=true
			if (IDOF(tempSelectedID)=IDOF(tempid))
				guicontrol,,ButtonRunFlow,% lang("Stopping")
		}
		else if (tempNewReceivedCommand["status"]="enabled")
		{
			if %tempid%enabled=false
			{
				%tempid%enabled=true
				SaveFlow(tempid)
			}
			else
				%tempid%enabled=true
			
			if (IDOF(tempSelectedID)=IDOF(tempid))
				guicontrol,,ButtonEnableFlow,% lang("Disable")
			
		}
		else if (tempNewReceivedCommand["status"]="disabled")
		{
			if %tempid%enabled=true
			{
				;It could happen that the other flows are closed right before the manager is closed. For example on shutdown. This is a try to prevent that the flows are disabled.
				;~ if shuttingDown
				;~ {
					%tempid%enabled=false
					FlowsToSaveSoon.Insert(tempid)
					SetTimer,saveFlows,2000 ;Wait 2 seconds and save then. If the manager is closed before that perioud, the flow will be enabled at next startup
				;~ }
				;~ else
				;~ {
					
				;~ }
				
			}
			else
				%tempid%enabled=false
			
			if (IDOF(tempSelectedID)=IDOF(tempid))
				guicontrol,,ButtonEnableFlow,% lang("Enable")
			
			
			
		
			
			
		}
		
		
		updateIcon(tempid)
		
	}
	else if (tempNewReceivedCommand["Function"]="AskFlowStatus")
	{
		logger("a2","Command received. Flow " tempNewReceivedCommand["SendingFlow"] " asks for status of "  tempNewReceivedCommand["flowname"])
		
		tempid:=IDOfName(tempNewReceivedCommand["flowname"],"flow")
		if tempid=
		{
			com_SendCommand({function: "AnswerFlowStatus", result: "NoSuchName", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
			;~ ControlSetText,edit1,AnswerFlowIsEnabled|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		}
		else
		{
			if (tempNewReceivedCommand["status"]="enabled")
			{
				
				if %tempid%enabled=true
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "enabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
					
					
				}
				else
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "disabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
					
				
			}
			else if (tempNewReceivedCommand["status"]="running")
			{
				if %tempid%running=true
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "running", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
					
					
				}
				else
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "stopped", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
			}
		}
		
	}
	else if (tempNewReceivedCommand["Function"]="ChangeFlowStatus")
	{
		logger("a2","Command received. Flow " tempNewReceivedCommand["SendingFlow"] " asks for status of "  tempNewReceivedCommand["flowname"])
		
		tempid:=IDOfName(tempNewReceivedCommand["flowname"],"flow")
		if tempid=
		{
			com_SendCommand({function: "AnswerFlowStatus", result: "NoSuchName", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
			;~ ControlSetText,edit1,AnswerFlowIsEnabled|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		}
		else
		{
			if (tempNewReceivedCommand["status"]="run")
			{
				
				if %tempid%enabled=true
				{
					if runflow(tempid,tempNewReceivedCommand)
					{
						com_SendCommand({function: "AnswerFlowStatus", result: "running", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
					}
					else
					{
						com_SendCommand({function: "AnswerFlowStatus", result: "stopped", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
					}
					
					
				}
				else
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "disabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
			}
			else if (tempNewReceivedCommand["status"]="stop")
			{
				
				
				if stopflow(tempid)
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "stopped", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
				else
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "running", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
				
				
			}
			else if (tempNewReceivedCommand["status"]="enable")
			{
				
				
				if enableflow(tempid)
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "enabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
				else
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "disabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
				
				
			}
			else if (tempNewReceivedCommand["status"]="disable")
			{
				
				
				if disableflow(tempid)
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "disabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
				else
				{
					com_SendCommand({function: "AnswerFlowStatus", result: "enabled", flowName: tempNewReceivedCommand["flowname"]},"editor",tempNewReceivedCommand["SendingFlow"]) ;Send the command to the Editor.
				}
				
				
			}
			
		}
		
	}
	
}
return

jumpovercommunicationlabels:
temp= ;do nothing