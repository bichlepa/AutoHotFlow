;Call a function in the Rendering thread in oder to make it rendering
API_Main_Exit()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.main.tasks.push({name: "exit"})
	LeaveCriticalSection(_cs_shared)
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}
API_Main_Thread_Stopped(par_ThreadID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.main.tasks.push({name: "ahkThreadStopped", threadID: par_ThreadID})
	LeaveCriticalSection(_cs_shared)
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_StartEditor(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.main.tasks.push({name: "StartEditor", flowID: par_FlowID})
	LeaveCriticalSection(_cs_shared)
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}
