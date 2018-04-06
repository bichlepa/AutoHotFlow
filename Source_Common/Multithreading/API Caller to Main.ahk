;Call a function in the Rendering thread in oder to make it rendering
API_Main_Exit()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.main.tasks.push({name: "exit"})
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}
API_Main_Thread_Stopped(par_ThreadID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.main.tasks.push({name: "ahkThreadStopped", threadID: par_ThreadID})
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_StartEditor(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.main.tasks.push({name: "StartEditor", flowID: par_FlowID})
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}
