API_manager_TreeView_ChangeFlowCategory(par_ID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadManager.ahkFunction("API_Call_manager_TreeView_ChangeFlowCategory", par_ID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}

API_manager_TreeView_AddEntry(par_Type, par_ID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := AhkThreadManager.ahkFunction("API_Call_manager_TreeView_AddEntry", par_Type, par_ID)
	logger("t2", A_ThisFunc " finished")
	
	return retvalue
	
}