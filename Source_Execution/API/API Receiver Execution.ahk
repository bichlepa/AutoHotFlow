API_Call_Execution_newInstance(p_FlowID)
{
	global _flows
	retvalue := newInstance(_flows[p_FlowID])
	return retvalue.id
}

API_Call_Execution_EnableTriggers(p_FlowID)
{
	global _flows
	retvalue := enableTriggers(_flows[p_FlowID])
	return retvalue.id
}

API_Call_Execution_DisableTriggers(p_FlowID)
{
	global _flows
	retvalue := disableTriggers(_flows[p_FlowID])
	return retvalue.id
}