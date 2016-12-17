API_Call_Execution_startFlow(p_FlowID)
{
	global _flows
	
	retvalue := startFlow(_flows[p_FlowID])
	return retvalue.id
}

API_Call_Execution_EnableTriggers(p_FlowID)
{
	global _flows
	retvalue := enableTriggers(_flows[p_FlowID])
	return retvalue.id
}
API_Call_Execution_StopFlow(p_FlowID)
{
	global _flows
	retvalue := stopFlow(_flows[p_FlowID])
	return retvalue.id
}
API_Call_Execution_RunToggleFlow(p_FlowID)
{
	global _flows
	retvalue := runToggleFlow(_flows[p_FlowID])
	return retvalue.id
}

API_Call_Execution_DisableTriggers(p_FlowID)
{
	global _flows
	retvalue := disableTriggers(_flows[p_FlowID])
	return retvalue.id
}

API_Call_Execution_enableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := enableOneTrigger(_flows[par_FlowID],_flows[par_FlowID].allelements[par_TriggerID])
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
API_Call_Execution_disableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := disableOneTrigger(_flows[par_FlowID],_flows[par_FlowID].allelements[par_TriggerID])
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
