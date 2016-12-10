API_Call_Execution_newInstance(p_FlowID)
{
	global _flows
	
	environment:=Object()
	environment.FlowID:=p_FlowID
	
	retvalue := newInstance(environment)
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

API_Call_Execution_DisableTriggers(p_FlowID)
{
	global _flows
	retvalue := disableTriggers(_flows[p_FlowID])
	return retvalue.id
}