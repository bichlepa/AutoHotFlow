API_Execution_startFlow(p_FlowID, par_PassedParsKey = "")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_startFlow", p_FlowID, par_PassedParsKey)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

API_Execution_EnableTriggers(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_EnableTriggers", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

API_Execution_StopFlow(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_StopFlow", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
API_Execution_ExecuteToggleFlow(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_ExecuteToggleFlow", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

API_Execution_DisableTriggers(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_DisableTriggers", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}


API_Execution_enableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_enableOneTrigger", par_FlowID, par_TriggerID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
API_Execution_disableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_disableOneTrigger", par_FlowID, par_TriggerID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

