
;Find flows in folder "saved Flows" und show them in the tv.
;Additionally read the state of flow and activate it if it should be active
;This function must be called once
FindFlows()
{
	global
	return parentAHKThread.ahkFunction("FindFlows")
}

;Create a new file for a flow
NewFlow(par_CategoryID = "")
{
	global
	return parentAHKThread.ahkFunction("NewFlow", par_CategoryID)
}


NewCategory(par_Newname = "")
{
	global
	return parentAHKThread.ahkFunction("NewCategory", par_Newname)
}

ChangeFlowCategory(par_FlowID, par_CategoryID)
{
	global
	return parentAHKThread.ahkFunction("ChangeFlowCategory", par_FlowID, par_CategoryID)
}

UpdateFlowCategoryName(par_FlowID)
{
	global
	return parentAHKThread.ahkFunction("UpdateFlowCategoryName", par_FlowID)
}

IDOfName(par_name,par_Type="") ;Returns the id by name
{
	global
	return parentAHKThread.ahkFunction("IDOfName", par_name, par_Type)
}


DeleteFlow(par_ID)
{
	global
	return parentAHKThread.ahkFunction("DeleteFlow", par_ID)
	
	
}

DeleteCategory(par_ID)
{
	global
	return parentAHKThread.ahkFunction("DeleteCategory", par_ID)
	
}