API_Call_Main_Draw()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := API_Draw_Draw()
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_SaveFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := SaveFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
	
}

API_Call_Main_SaveFlowMetaData(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := SaveFlowMetaData(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_enableFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := enableFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_enableToggleFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := enableToggleFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_editFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := editFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_stopFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := stopFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_runFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := runFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_runToggleFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := runToggleFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_triggerFlow(par_FlowID, par_Reason)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := triggerFlow(par_FlowID, par_Reason)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_Element_New(p_FlowID, p_type="",p_elementID="")
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := Element_New(p_FlowID, p_type,p_elementID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_Connection_New(p_FlowID, p_elementID="")
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	retval := Connection_New(p_FlowID,p_elementID )
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_Element_SetType(p_FlowID, p_elementID,p_elementType)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := Element_SetType(p_FlowID, p_elementID,p_elementType)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_Element_SetClass(p_FlowID, p_elementID, p_elementClass)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := Element_SetClass(p_FlowID, p_elementID, p_elementClass)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_Element_setParameterDefaults(p_FlowID, p_elementID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := Element_setParameterDefaults(p_FlowID, p_elementID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_Element_Remove(p_FlowID, p_elementID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := Element_Remove(p_FlowID, p_elementID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_main_State_New(p_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := state_New(p_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
API_Call_main_State_Undo(p_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := state_Undo(p_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
API_Call_main_State_Redo(p_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := state_Redo(p_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
API_Call_main_State_RestoreCurrent(p_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := state_RestoreCurrent(p_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}


API_Call_main_Exit()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := exit()
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}