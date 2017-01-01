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
	_flows[FlowID].draw.mustDraw := true
	return
	
	
	local retvalue
	logger("t2", A_ThisFunc " called")
	if (_share.drawActive == true)
	{
		_flows[FlowID].draw.mustDraw := true
	}
	else
	{
		_flows[FlowID].draw.mustDraw := true
		;~ retvalue := parentAHKThread.ahkFunction("API_Call_Main_Draw")
	}
	logger("t2", A_ThisFunc " finished")
	return retvalue
}


API_Main_LoadFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_LoadFlow", par_FlowID)
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

API_Main_enableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_enableOneTrigger", par_FlowID, par_TriggerID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}
API_Main_disableOneTrigger(par_FlowID, par_TriggerID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_disableOneTrigger", par_FlowID, par_TriggerID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_setDefaultTrigger(par_FlowID, par_TriggerID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_setDefaultTrigger", par_FlowID, par_TriggerID)
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

API_Main_disableFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_DisableFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_executeFlow(par_FlowID, par_TriggerID = "", par_PassedParsKey = "" )
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_ExecuteFlow", par_FlowID, par_TriggerID, par_PassedParsKey)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Main_executeToggleFlow(par_FlowID)
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_executeToggleFlow", par_FlowID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

;~ API_Main_triggerFlow(par_FlowID, par_Reason)
;~ {
	;~ global
	;~ local retvalue
	;~ logger("t2", A_ThisFunc " called")
	;~ retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_triggerFlow", par_FlowID, par_Reason)
	;~ logger("t2", A_ThisFunc " finished")
	;~ return retvalue
;~ }



API_Main_Element_New(p_FlowID, p_type="",p_elementID="")
{
	global
	local retvalue
	logger("t2", A_ThisFunc " called")
	retvalue :=  parentAHKThread.ahkFunction("API_Call_Main_Element_New", p_FlowID, p_type, p_elementID)
	logger("t2", A_ThisFunc " finished")
	return retvalue
}


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

