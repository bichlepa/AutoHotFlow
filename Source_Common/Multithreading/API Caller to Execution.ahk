;This file is included by all threads which want to communicate to execution thread

; tells the execution thread that it should start a flow
API_Execution_ExecuteFlow(p_FlowID, par_TriggerID ="", p_instanceVars = "", p_instanceProperties = "")
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "ExecuteFlow", flowID: p_FlowID, TriggerID: par_TriggerID, instanceVars: p_instanceVars, instanceProperties: p_instanceProperties})
}

; tells the execution thread that it should enable all triggers of a flow
API_Execution_EnableTriggers(p_FlowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "EnableTriggers", flowID: p_FlowID})
}

; tells the execution thread that it should stop the execution of a flow
API_Execution_StopFlow(p_FlowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "StopFlow", flowID: p_FlowID})
}

; tells the execution thread that it should start or stop a flow
API_Execution_ExecuteToggleFlow(p_FlowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "ExecuteToggleFlow", flowID: p_FlowID})
}

; tells the execution thread that it should disable all triggers of a flow
API_Execution_DisableTriggers(p_FlowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "DisableTriggers", flowID: p_FlowID})
}

; tells the execution thread that it should enable a single trigger
API_Execution_enableOneTrigger(par_FlowID, par_TriggerID, par_save = true)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "enableOneTrigger", flowID: par_FlowID, triggerID: par_TriggerID, save: par_save})
}

; tells the execution thread that it should disable a single trigger
API_Execution_disableOneTrigger(par_FlowID, par_TriggerID, par_save = true)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "disableOneTrigger", flowID: par_FlowID, triggerID: par_TriggerID, save: par_save})
}

;When an element has been using a separate thread in order to execute some code, this thread calls this function
API_Execution_externaElementFinish(par_UniqueID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "externalElementFinish", uniqueID: par_UniqueID})
}

;When a trigger has been using a separate thread in order to execute some code, this thread calls this function
API_Execution_externalTrigger(par_UniqueID, par_iteration)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("execution", {name: "externalTrigger", uniqueID: par_UniqueID, iteration: par_iteration})
}

