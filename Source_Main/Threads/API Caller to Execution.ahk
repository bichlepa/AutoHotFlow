API_Execution_newInstance(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadExecution1.ahkFunction("API_Call_Execution_newInstance", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
