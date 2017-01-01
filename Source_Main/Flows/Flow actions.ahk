editFlow(par_FlowID)
{
	global
	local FoundThreadID, oneThreadID, oneThread
	;~ d(global_AllThreads)
	
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	
	;Check whether there is already a Editor opened for that flow
	FoundThreadID := ""
	for oneThreadID, oneThread in global_AllThreads
	{
		if (oneThread.type = "editor")
		{
			if (oneThread.FlowID = par_FlowID)
			{
				FoundThreadID:= oneThreadID
				break
			}
		}
	}
	if (FoundThreadID != "")
	{
		API_Editor_EditGUIshow(par_FlowID)
		
		
	}
	else
	{
		Thread_StartEditor(par_FlowID)
	}
}

enableFlow(par_FlowID)
{
	global
	local oneTriggerID, oneTrigger
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	
	API_Execution_EnableTriggers(par_FlowID)
	SaveFlowMetaData(par_FlowID)
}
enableToggleFlow(par_FlowID)
{
	global
	
	if (_flows[par_FlowID].enabled != true)
	{
		enableFlow(par_FlowID)
	}
	else
	{
		disableFlow(par_FlowID)
	}
}

disableFlow(par_FlowID)
{
	API_Execution_DisableTriggers(par_FlowID)
	SaveFlowMetaData(par_FlowID)
}

enableOneTrigger(par_FlowID, par_TriggerID = "", save=True)
{
	global _flows
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	API_Execution_enableOneTrigger(par_FlowID, par_TriggerID)
	if (save)
		SaveFlowMetaData(par_FlowID)
}

disableOneTrigger(par_FlowID, par_TriggerID = "", save=True)
{
	API_Execution_disableOneTrigger(par_FlowID, par_TriggerID)
	if (save)
		SaveFlowMetaData(par_FlowID)
}

ExecuteFlow(par_FlowID, par_TriggerID, par_PassedParsKey)
{
	global _flows
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	API_Execution_startFlow(par_FlowID, par_TriggerID, par_PassedParsKey)
}

ExecuteToggleFlow(par_FlowID)
{
	global _flows
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	API_Execution_ExecuteToggleFlow(par_FlowID)
}

TriggerFlow(par_FlowID, par_Reason)
{
	global _flows
	if (_flows[par_FlowID].loaded != true)
	{
		LoadFlow(par_FlowID)
	}
	API_Execution_startFlow(par_FlowID)
}

StopFlow(par_FlowID)
{
	API_Execution_StopFlow(par_FlowID)
}

StopAllFlows()
{
	MsgBox The function %A_ThisFunc% is not implemented yet
}

StopFlowInstance(par_FlowID, par_InstanceID)
{
	MsgBox The function %A_ThisFunc% is not implemented yet
}