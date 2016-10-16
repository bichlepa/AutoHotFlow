

API_Editor_CreateMarkedList(par_FlowID)
{
	global
	
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	
	;~ MsgBox %par_FlowID%
	;~ d(global_Allthreads)
	for threadID, threadpars in global_Allthreads
	{
		;~ d(threadpars)
		if (threadpars.flowID = par_FlowID)
		{
			;~ MsgBox ja
			retvalue := AhkThread%threadID%.ahkFunction("API_Call_Editor_CreateMarkedList")
			break
		}
	}
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}



API_Editor_EditGUIshow(par_FlowID)
{
	global
	
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	for threadID, threadpars in global_Allthreads
	{
		if (threadpars.flowID = par_FlowID)
		{
			retvalue := AhkThread%threadID%.ahkFunction("API_Call_Editor_EditGUIshow")
			break
		}
	}
	
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}