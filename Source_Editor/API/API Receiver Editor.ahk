API_Call_Editor_CreateMarkedList()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	retval := CreateMarkedList()
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}

API_Call_Editor_EditGUIshow()
{
	global
	local retval
	logger("t2", A_ThisFunc " call received")
	
	;Do not execute EditGUIshow() directly. Otherwise this would cause a call to main thread. But it is blocked, because the main thread is currently executin this function.
	settimer, EditGUIshow, -10
	
	logger("t2", A_ThisFunc " call finished")
	return retval
}