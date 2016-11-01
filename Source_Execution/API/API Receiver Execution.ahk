API_Call_Execution_newInstance(p_FlowID)
{
	global _flows
	retvalue := newInstance(_flows[p_FlowID])
	return retvalue.id
}