API_manager_TreeView_Refill()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.manager.tasks.push({name: "TreeView_Refill"})
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}


API_manager_TreeView_AddEntry(par_Type, par_ID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.manager.tasks.push({name: "TreeView_AddEntry", type:par_Type, id: par_ID})
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
API_manager_TreeView_Select(par_Type, par_ID, par_options = "")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.manager.tasks.push({name: "TreeView_Select", type:par_Type, id: par_ID, options: par_options})
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
API_Manager_ShowWindow()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_share.manager.tasks.push({name: "ShowWindow"})
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}