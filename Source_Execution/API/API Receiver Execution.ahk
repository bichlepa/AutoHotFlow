API_Call_Execution_startFlow(p_FlowID, par_TriggerID, par_PassedParsKey)
{
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
	retvalue := enableTriggers(_flows[p_FlowID])
	return retvalue.id
}
API_Call_Execution_StopFlow(p_FlowID)
{
	retvalue := stopFlow(_flows[p_FlowID])
	return retvalue.id
}
API_Call_Execution_ExecuteToggleFlow(p_FlowID)
{
	retvalue := ExecuteToggleFlow(_flows[p_FlowID])
	return retvalue.id
}

API_Call_Execution_DisableTriggers(p_FlowID)
{
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

API_Call_Execution_externalTrigger(par_UniqueID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := ExecuteInNewAHKThread_trigger(par_UniqueID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Execution_externalFlowFinish(par_UniqueID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := ExecuteInNewAHKThread_finishedExecution(par_UniqueID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
