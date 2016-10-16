

API_Call_Manager_TreeView_ChangeFlowCategory(par_ID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := TreeView_manager_ChangeFlowCategory(par_ID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}


API_Call_Manager_TreeView_AddEntry(par_Type, par_ID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := TreeView_manager_AddEntry(par_Type, par_ID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}