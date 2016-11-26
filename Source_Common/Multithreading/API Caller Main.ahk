;Call a function in the Rendering thread in oder to make it rendering
API_Main_Exit()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := parentAHKThread.ahkFunction("API_Call_Main_Exit")
	logger("t2", A_ThisFunc " finished")
	return retvalue
}
API_Main_Thread_Stopped(par_ThreadID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	retvalue := parentAHKThread.ahkFunction("API_Call_Main_Thread_Stopped",par_ThreadID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_Draw()
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	_flows[FlowID].draw.mustDraw := true
	
	retvalue := parentAHKThread.ahkFunction("API_Call_Main_Draw")
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_SaveFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue := parentAHKThread.ahkFunction("API_Call_Main_SaveFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_SaveFlowMetaData(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_SaveFlowMetaData", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_enableFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_EnableFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_enableToggleFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_enableToggleFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_editFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_EditFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_stopFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_StopFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_runFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_RunFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_runToggleFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_runToggleFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_triggerFlow(par_FlowID, par_Reason)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_triggerFlow", par_FlowID, par_Reason)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}



API_Main_Element_New(p_FlowID, p_type="",p_elementID="")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Element_New", p_FlowID, p_type, p_elementID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

;~ API_Main_Trigger_New(p_FlowID, p_elementID, p_TriggerID="")
;~ {
	;~ global
	;~ local retvalue
	;~ logger("t2", A_ThisFunc " called")
	;~ retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Trigger_New", p_FlowID, p_elementID, p_TriggerID)
	;~ logger("t2", A_ThisFunc " finished")
	;~ return retvalue
;~ }

;~ API_Main_Trigger_Remove(p_FlowID, p_TriggerID="")
;~ {
	;~ global
	;~ local retvalue
	;~ logger("t2", A_ThisFunc " called")
	;~ retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Trigger_New", p_FlowID, p_TriggerID="")
	;~ logger("t2", A_ThisFunc " finished")
	;~ return retvalue
;~ }

API_Main_Connection_New(p_FlowID, p_elementID="")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Connection_New", p_FlowID, p_elementID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}


API_Main_Element_SetType(p_FlowID, p_elementID,p_elementType)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Element_SetType", p_FlowID, p_elementID,p_elementType)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_Element_SetClass(p_FlowID, p_elementID, p_elementClass)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Element_SetClass", p_FlowID, p_elementID, p_elementClass)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_Element_setParameterDefaults(p_FlowID, p_elementID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Element_setParameterDefaults", p_FlowID, p_elementID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_Element_Remove(p_FlowID, p_elementID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Element_Remove", p_FlowID, p_elementID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_State_New(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_State_New", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_State_Undo(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_State_Undo", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_State_Redo(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_State_Redo", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_State_RestoreCurrent(p_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_State_RestoreCurrent", p_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

;~ GetListContainingElement(p_Flow_ID, p_ElementID)
;~ {
	;~ global
	;~ local listID
	;~ listid := parentAHKThread.ahkFunction(p_Flow_ID, p_ElementID, true)
	;~ return object(listID)
;~ }

