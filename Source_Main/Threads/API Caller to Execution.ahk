API_Execution_newInstance(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_newInstance", p_FlowID)
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

API_Execution_DisableTriggers(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_DisableTriggers", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

