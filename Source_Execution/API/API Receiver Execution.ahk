API_Call_Execution_startFlow(p_FlowID, par_TriggerID, par_PassedParsKey)
{
	global _flows, _share
	
	if (par_PassedParsKey!= "")
	{
		if (_share.temp.haskey(par_PassedParsKey))
		{
			;~ d(_share.temp[par_PassedParsKey], "aiöhio")
			params:=Object()
			params.VarsToPass:=_share.temp[par_PassedParsKey].varstoPass
			params.CallBack:=_share.temp[par_PassedParsKey].CallBack
			params.Wait:=_share.temp[par_PassedParsKey].Wait
			_share.temp.delete(par_PassedParsKey)
		}
	}
	retvalue := startFlow(_flows[p_FlowID], _flows[p_FlowID].allElements[par_TriggerID], params)
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
API_Call_Execution_ExecuteToggleFlow(p_FlowID)
{
	global _flows
	retvalue := ExecuteToggleFlow(_flows[p_FlowID])
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

API_Call_Execution_externalFlowFinish(par_UniqueID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := x_ExecuteInNewThread_finishedExecution(par_UniqueID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
