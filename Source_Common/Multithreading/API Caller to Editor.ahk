;This file is included by all threads which want to communicate to editor thread

; tells the editor thread that it should show the gui
API_Editor_EditGUIshow(par_FlowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("editor" par_FlowID, {name: "EditGUIshow"})
}

; tells the editor thread that it should exit
API_Editor_Exit(par_flowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("editor" par_FlowID, {name: "exit"})
}