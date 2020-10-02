
; open flow editor to edit the defined flow
editFlow(p_FlowID)
{
	; warn user if he opens a demo flow (suppress warding during development)
	if (_getFlowProperty(p_FlowID, "demo") and _getSettings("developing") != True)
	{
		MsgBox, 48, % lang("Edit flow"), % lang("You are opening a demonstration flow for edit.") " " lang("Please be aware that a demonstration flow cannot be changed.") " " lang("You may duplicate this flow first and then you can edit it.")
	}
	
	; open the editor
	API_Main_StartEditor(p_FlowID)
}

; enable all triggers in a flow
enableFlow(p_FlowID)
{
	; enable the triggers
	API_Execution_EnableTriggers(p_FlowID)
}

; changes the flow enable state
enableToggleFlow(p_FlowID)
{
	if (not _getFlowProperty(p_FlowID, "enabled"))
	{
		; flow is disabled, enable it
		enableFlow(p_FlowID)
	}
	else
	{
		; flow is enabled, disable it
		disableFlow(p_FlowID)
	}
}

; disable all triggers in a flow
disableFlow(p_FlowID)
{
	; disable the triggers
	API_Execution_DisableTriggers(p_FlowID)
}

; enable only one trigger
enableOneTrigger(p_FlowID, p_TriggerID = "", p_save=True)
{
	; enable the trigger
	API_Execution_enableOneTrigger(p_FlowID, p_TriggerID, p_save)
}

; disable only one trigger
disableOneTrigger(p_FlowID, p_TriggerID = "", p_save=True)
{
	; disable the trigger
	API_Execution_disableOneTrigger(p_FlowID, p_TriggerID, p_save)
}

; execute a flow
; trigp_TriggerID: TriggerID is optional. If not set, the default manual trigger will be triggered
; p_params: more parameters (see comment to ExecuteFlow() in "Instances and Treads.ahk")
ExecuteFlow(p_FlowID, p_TriggerID="", p_params="")
{
	; execute the flow
	API_Execution_ExecuteFlow(p_FlowID, p_TriggerID, p_params)
}

; change execution state
; if flow is executing, it will be stopped.
; if flow is not executing, the default main trigger will be triggered (if any)
ExecuteToggleFlow(p_FlowID)
{
	; change execution state
	API_Execution_ExecuteToggleFlow(p_FlowID)
}

; Stop the execution of a flow
StopFlow(p_FlowID)
{
	API_Execution_StopFlow(p_FlowID)
}

; Stop the execution of all flow (todo: implement and use on exit)
StopAllFlows()
{
	MsgBox The function %A_ThisFunc% is not implemented yet
}
