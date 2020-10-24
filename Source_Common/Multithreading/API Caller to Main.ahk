;This file is included by all threads which want to communicate to main thread

; tells the main thread that it has to exit
API_Main_Exit()
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	_setTask("main", {name: "exit"})
}

; tells the main thread that the current thread has stopped. Is called before call of Exitapp
API_Main_Thread_Stopped(par_ThreadID)
{
	; do not use _setTask() and do not log because we cannot use _EnterCriticalSection anymore
	EnterCriticalSection(_cs_shared)
    _share.Tasks["main"].push({name: "ahkThreadStopped", threadID: par_ThreadID})
	LeaveCriticalSection(_cs_shared)
}

; tells the main thread that it has to open the editor for a flow
API_Main_StartEditor(par_FlowID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("main", {name: "StartEditor", flowID: par_FlowID})
}

; tells the main thread that it has to start a new element AHK thread
; such threads are used for some triggers and elements
API_Main_StartElementAhkThread(par_UniqueID, par_code)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("main", {name: "StartElementAhkThread", uniqueID: par_UniqueID, code: par_code})
}

; tells the main thread that it has to stop an element AHK thread
; such threads are used for some triggers and elements
API_Main_StopElementAhkThread(par_UniqueID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setTask("main", {name: "StopElementAhkThread", uniqueID: par_UniqueID})
}

; tells the main thread that an element AHK thread has stopped
; this function is called from the external AHK thread
API_Main_ElementThread_Stopped(par_UniqueID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
    _share.Tasks["main"].push({name: "elementAhkThreadStopped", uniqueID: par_UniqueID})
}

; tells the main thread that an element (of type trigger) AHK thread wants to trigger a flow
; this function is called from the external AHK thread
API_Main_ElementThread_Trigger(par_UniqueID)
{
	logger("t2", A_ThisFunc " called from thread", _ahkThreadID)
	_setTask("main", {name: "elementAhkThreadTrigger", uniqueID: par_UniqueID})
}