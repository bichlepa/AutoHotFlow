


API_Editor_EditGUIshow(par_FlowID)
{
	global
	
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("editor" par_FlowID, {name: "EditGUIshow"})
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}

API_Editor_Exit(par_flowID)
{
	global
	
	local retvalue
	logger("t2", A_ThisFunc " called")
	
	_setTask("editor" par_FlowID, {name: "exit"})
	
	logger("t2", A_ThisFunc " finished")
	return retvalue
}