API_Execution_startFlow(p_FlowID, par_TriggerID ="", par_PassedParsKey = "")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_startFlow", p_FlowID, par_TriggerID, par_PassedParsKey)
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

;When an element has been using a separate thread in order to execute some code, this thread calls this function
API_Execution_externalFlowFinish(par_UniqueID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_externalFlowFinish", par_UniqueID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

;When a trigger has been using a separate thread in order to execute some code, this thread calls this function
API_Execution_externalTrigger(par_UniqueID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_externalTrigger", par_UniqueID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

