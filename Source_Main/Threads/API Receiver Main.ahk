API_Call_Main_Draw()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := API_Draw_Draw()
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_write_settings()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := write_settings()
	
	logger("t2", A_ThisFunc " call finished")
	return retval
	
}
API_Call_Main_LoadFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := LoadFlow(par_FlowID)
	
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

API_Call_Main_enableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := enableOneTrigger(par_FlowID, par_TriggerID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}
API_Call_Main_disableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := disableOneTrigger(par_FlowID, par_TriggerID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_setDefaultTrigger(par_FlowID, par_TriggerID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := Element_setDefaultTrigger(par_FlowID, par_TriggerID)
	
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
API_Call_Main_disableFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := disableFlow(par_FlowID)
	
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

API_Call_Main_executeFlow(par_FlowID, par_TriggerID, par_PassedParsKey)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := executeFlow(par_FlowID, par_TriggerID, par_PassedParsKey)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_executeToggleFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := executeToggleFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

;~ API_Call_Main_triggerFlow(par_FlowID, par_Reason)
;~ {
	;~ global
	;~ local retval
	;~ logger("t2", A_ThisFunc " call received")
	
	;~ retval := triggerFlow(par_FlowID, par_Reason)
	
	;~ logger("t2", A_ThisFunc " call finished")
	;~ return retval
;~ }


API_Call_Main_NewFlow(par_CategoryID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := NewFlow(par_CategoryID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_InitFlow(par_Filepath)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := InitFlow(par_Filepath)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}


API_Call_Main_NewCategory(par_Newname)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := NewCategory(par_Newname)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_ChangeFlowCategory(par_FlowID, par_CategoryID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := ChangeFlowCategory(par_FlowID, par_CategoryID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}


API_Call_Main_UpdateFlowCategoryName(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := UpdateFlowCategoryName(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_DuplicateFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := DuplicateFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_DeleteFlow(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := DeleteFlow(par_FlowID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Main_DeleteCategory(par_FlowID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := DeleteCategory(par_FlowID)
	
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
API_Call_Main_Thread_Stopped(par_ThreadID)
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	retval := Thread_Stopped(par_ThreadID)
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}