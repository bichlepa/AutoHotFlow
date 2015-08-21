goto,jumpovercommunicationlabels

;Create a hidden window to allow other triggers or manager to send messages 
com_CreateHiddenReceiverWindow()
{
	global
	gui,CommandWindow:default
	gui,CommandWindow:new,,CommandWindowOfEditor
	gui,add,text,vCommandWindowFlowName w200,----§%CurrentManagerHiddenWindowID%§
	gui,add,edit,vCommandWindowRecieve gCommandWindowRecieve w200 
	;~ gui,show ,w800 ;Only for debugging
	
}


;React on commands from other ahks
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
	
	
	;Evaluating command
	;Manager wants the flow to start
	if (tempNewReceivedCommand["Function"]="run")
	{
		logger("a2","Command received to start run.")
		
		r_startRun(tempNewReceivedCommand)
		
	}
	;A trigger or an action of other flow wants the flow to start
	else if (tempNewReceivedCommand["Function"]="trigger")
	{
		if tempNewReceivedCommand["ElementID"]
		{
			logger("a2","Command received to trigger the flow.")
			r_trigger(tempNewReceivedCommand["ElementID"],tempNewReceivedCommand)
		}
		else
		{
			logger("a0","Error: Command received to trigger the flow, but no Element ID given.")
		}
		
		
	}
	;Manager wants the flow to stop
	else if (tempNewReceivedCommand["Function"]="stop")
	{
		stopRun:=true
		logger("a2","Command received to stop run.")
		
	}
	;Manager or other flow wants this flow to enable
	else if (tempNewReceivedCommand["Function"]="enable")
	{
		
		logger("a2","Command received to enable flow.")
		if (triggersEnabled=false)
			goto,ui_Menu_Enable
		
	}
	;Manager or other flow wants this flow to disable
	else if (tempNewReceivedCommand["Function"]="disable")
	{
		logger("a2","Command received to disable flow.")
		if (triggersEnabled=true)
			goto,ui_Menu_Enable
		
	}
	;Manager wants this flow to show the edit window
	else if (tempNewReceivedCommand["Function"]="edit")
	{
		ui_showgui()
		logger("a2","Command received to show the edit window.")
		
	}
	;An executed generated script element has finished
	else if (tempNewReceivedCommand["Function"]="ElementEnd")
	{
		if not tempNewReceivedCommand["ElementID"]
		{
			logger("a0","Error: Command received to end element, but no Element ID given.")
			
		}
		else if not tempNewReceivedCommand["Result"]
		{
			logger("a0","Error: Command received to end element, but no Result given.")
		}
		else
		{
			logger("a2","Command received to end element " tempNewReceivedCommand["ElementID"] " with result: " tempNewReceivedCommand["Result"])
			MarkThatElementHasFinishedRunningOneVar(tempNewReceivedCommand["ElementID"],tempNewReceivedCommand["Result"])
		}
	}
	;Manager flow asks this flow to report current status
	else if (tempNewReceivedCommand["Function"]="UpdateStatus")
	{
		logger("a3","Command received to report current status.")
		if (triggersEnabled=true)
			com_SendCommand({function: "ReportStatus",status: "enabled"},"manager") ;Send the command to the Manager.
		else
			com_SendCommand({function: "ReportStatus",status: "disabled"},"manager") ;Send the command to the Manager.
		if (nowRunning!=true)
			com_SendCommand({function: "ReportStatus",status: "stopped"},"manager") ;Send the command to the Manager.
		else
			com_SendCommand({function: "ReportStatus",status: "running"},"manager") ;Send the command to the Manager.

	}
	;Manager answers the request about the status of a flow
	else if (tempNewReceivedCommand["Function"]="AnswerFlowStatus")
	{
		logger("a2","Command received with answer of the flow status.")
		;~ ToolTip % strobj(tempNewReceivedCommand)
		returnedFlowStatus:=tempNewReceivedCommand.clone()
	}
	;Manager answers the request about the status of a flow
	else if (tempNewReceivedCommand["Function"]="AnswerFlowStatusChanged")
	{
		logger("a2","Command received with answer of the changed flow status.")
		;~ ToolTip % strobj(tempNewReceivedCommand)
		returnedFlowStatus:=tempNewReceivedCommand.clone()
	}
	;Called flow tells that it has finished
	else if (tempNewReceivedCommand["Function"]="CalledFlowHasFinished")
	{
		logger("a2","Command received with answer from called flow that is has finished.")
		;~ ToolTip % strobj(tempNewReceivedCommand)
		v_ImportLocalVariablesFromObject(tempNewReceivedCommand["CallerInstanceID"],tempNewReceivedCommand["localVariables"])
		MarkThatElementHasFinishedRunning(tempNewReceivedCommand["CallerInstanceID"],tempNewReceivedCommand["CallerThreadID"],tempNewReceivedCommand["CallerElementID"],tempNewReceivedCommand["CallerElementIDInInstance"],"normal")
		;~ MsgBox % "finished`n" strobj(tempNewReceivedCommand)
	}
	;Generated script action, condition or loop tells that it has finished
	else if (tempNewReceivedCommand["Function"]="GeneratedScriptHasFinished")
	{
		logger("a2","Command received with answer from generated script that is has finished.")
		;~ ToolTip % strobj(tempNewReceivedCommand)
		;~ MsgBox % strobj(tempNewReceivedCommand["localVariables"])
		v_ImportLocalVariablesFromObject(tempNewReceivedCommand["InstanceID"],tempNewReceivedCommand["localVariables"])
		v_ImportThreadVariablesFromObject(tempNewReceivedCommand["InstanceID"],tempNewReceivedCommand["ThreadID"],tempNewReceivedCommand["threadVariables"])
		temptype:=%ElementID%type
		tempsubtype:=%ElementID%subtype
		
		tempresult:=tempNewReceivedCommand["result"]
		if not (tempresult="normal" or tempresult = "exception" or tempresult = "yes" or tempresult = "no")
			tempresult=normal
		
		MarkThatElementHasFinishedRunning(tempNewReceivedCommand["InstanceID"],tempNewReceivedCommand["ThreadID"],tempNewReceivedCommand["ElementID"],tempNewReceivedCommand["ElementIDInInstance"],tempresult)
		
		stopOneElement%temptype%%tempsubtype%(tempNewReceivedCommand["InstanceID"],tempNewReceivedCommand["ThreadID"],tempNewReceivedCommand["ElementID"],tempNewReceivedCommand["ElementIDInInstance"])
		;~ MsgBox % "finished`n" strobj(tempNewReceivedCommand)
	}
	;Manager tells that flow parameters (like flow name) has changed
	else if (tempNewReceivedCommand["Function"]="FlowParametersChanged")
	{
		logger("a2","Command received to reload general flow parameters.")
		i_loadGeneralParameters()
	}
	;Manager tells that language has changed
	else if (tempNewReceivedCommand["Function"]="languageChanged")
	{
		logger("a2","Command received to change language.")
		lang_LoadCurrentLanguage()
		ui_OnLanguageChange()
	}
	;Manager wants the flow to immediately exit
	else if (tempNewReceivedCommand["Function"]="immediatelyexit")
	{
		logger("a2","Command received to emmediately exit.")
		immediatelyexit=true
		exitapp
	}
	;Manager wants the flow to exit. If not saved the flow will show a dialogue
	else if (tempNewReceivedCommand["Function"]="exit")
	{
		logger("a2","Command received to exit.")
		exitapp
	}
	;Manager wants the flow to exit. If not saved the flow will show a dialogue
	else if (tempNewReceivedCommand["Function"]="nothing")
	{
		nothing= ;Do nothing
	}
	else
	{
		logger("a2","Command window received an unknown command: " tempCommand)
		MsgBox % "Command window received an unknown command: `n" tempCommand
	}
	
	
	
	
	
	
}
return

jumpovercommunicationlabels:
temp= ;do nothing