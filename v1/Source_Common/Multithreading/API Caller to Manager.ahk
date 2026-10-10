;This file is included by all threads which want to communicate to manager thread

; tells the manager thread that it should refill the treeview
API_manager_TreeView_Refill()
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("manager", {name: "TreeView_Refill"})
}

; tells the manager thread that it should show the window
API_Manager_ShowWindow()
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("manager", {name: "ShowWindow"})
	
}
