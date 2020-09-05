API_manager_TreeView_Refill()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.manager.tasks.push({name: "TreeView_Refill"})
	LeaveCriticalSection(_cs_shared)

	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}


API_manager_TreeView_AddEntry(par_Type, par_ID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.manager.tasks.push({name: "TreeView_AddEntry", type:par_Type, id: par_ID})
	LeaveCriticalSection(_cs_shared)
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
API_manager_TreeView_Select(par_Type, par_ID, par_options = "")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.manager.tasks.push({name: "TreeView_Select", type:par_Type, id: par_ID, options: par_options})
	LeaveCriticalSection(_cs_shared)
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
API_Manager_ShowWindow()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	EnterCriticalSection(_cs_shared)
	_share.manager.tasks.push({name: "ShowWindow"})
	LeaveCriticalSection(_cs_shared)
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
