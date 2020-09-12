API_manager_TreeView_Refill()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("manager", {name: "TreeView_Refill"})

	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

API_Manager_ShowWindow()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("manager", {name: "ShowWindow"})
	
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}
