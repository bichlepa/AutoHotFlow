API_Execution_startFlow(p_FlowID, par_TriggerID ="", p_Params = "")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "startFlow", flowID: p_FlowID, TriggerID: par_TriggerID, Params: p_Params})
	
	logger("t2", A_ThisFunc " finished")
	return
}

API_Execution_EnableTriggers(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "EnableTriggers", flowID: p_FlowID})
	
	logger("t2", A_ThisFunc " finished")
	return
}

API_Execution_StopFlow(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "StopFlow", flowID: p_FlowID})
	
	logger("t2", A_ThisFunc " finished")
	return
}
API_Execution_ExecuteToggleFlow(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "ExecuteToggleFlow", flowID: p_FlowID})
	
	logger("t2", A_ThisFunc " finished")
	return
}

API_Execution_DisableTriggers(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "DisableTriggers", flowID: p_FlowID})
	
	logger("t2", A_ThisFunc " finished")
	return
}


API_Execution_enableOneTrigger(par_FlowID, par_TriggerID, par_save = true)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "enableOneTrigger", flowID: par_FlowID, triggerID: par_TriggerID, save: par_save})
	
	logger("t2", A_ThisFunc " finished")
	return
}

API_Execution_disableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "disableOneTrigger", flowID: par_FlowID, triggerID: par_TriggerID})
	
	logger("t2", A_ThisFunc " finished")
	return
}

;When an element has been using a separate thread in order to execute some code, this thread calls this function
API_Execution_externaElementFinish(par_UniqueID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "externalElementFinish", uniqueID: par_UniqueID})
	
	logger("t2", A_ThisFunc " finished")
	return
}

;When a trigger has been using a separate thread in order to execute some code, this thread calls this function
API_Execution_externalTrigger(par_UniqueID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("execution", {name: "externalTrigger", uniqueID: par_UniqueID})
	
	logger("t2", A_ThisFunc " finished")
	return
}

