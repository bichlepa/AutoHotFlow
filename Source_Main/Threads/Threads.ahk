; define some super-global variables
global global_EditorThreadIDCounter = 1
global global_AllThreads := Object()
global global_CommonAhkCodeForAllThreads:=""
global global_elementInclusions := ""

; initialize some variables
Thread_init()
{
	; initialize the code which will be inserted in all threads
	; it contains the references to the critical sections and critical variables which are shared among all threads
	global_CommonAhkCodeForAllThreads := "global _cs_shared := " _cs_shared "`n "
	global_CommonAhkCodeForAllThreads .= "global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ") `n"

}

; start the manager thread
Thread_StartManager()
{
	; prepare variable which will be used to pass tasks or information to this thread
	_setSharedProperty("tasks.manager", object())
	
	; define thread ID
	threadID := "Manager"
	logger("t1", "Starting manager thread. ID: " threadID)

	; read source file
	FileRead, ExecutionThreadCode, % _ScriptDir "\Source_Manager\Manager.ahk"

	; replace placeholders
	StringReplace, ExecutionThreadCode, ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_libInclusionsForThreads global_elementInclusionsForThreads

	; start the new thread
	newThread := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	
	; write thread ID to the list of all threads
	global_AllThreads[threadID] := {permanent: true, type: "Manager", thread: newThread}

	logger("t1", "Manager thread started")
	return threadID
}

; start an editor thread
Thread_StartEditor(p_FlowID)
{
	; prepare variable which will be used to pass tasks or information to this thread
	_setSharedProperty("tasks." "editor" p_FlowID, object())
	
	; define thread ID
	threadID := "Editor" global_EditorThreadIDCounter++
	logger("t1", "Starting editor thread. ID: " threadID)

	; read source file
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Editor\Editor.ahk"

	; replace placeholders
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_libInclusionsForThreads global_elementInclusionsForThreads

	; start the new thread
	newThread := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n global _FlowID := """ p_FlowID """`n"  ExecutionThreadCode)
	
	; write thread ID to the list of all threads
	global_AllThreads[threadID] := {permanent: false, type: "Editor", flowID: p_FlowID, thread: newThread}

	logger("t1", "Editor thread started")
	return threadID
}

; start the draw thread
Thread_StartDraw()
{
	; prepare variable which will be used to pass tasks or information to this thread
	_setSharedProperty("tasks.draw", object())
	
	; define thread ID
	threadID := "Draw"
	logger("t1", "Starting draw thread. ID: " threadID)

	; read source file
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Draw\Draw.ahk"

	; start the new thread
	newThread := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	
	; write thread ID to the list of all threads
	global_AllThreads[threadID] := {permanent: true, type: "Draw", thread: newThread}

	logger("t1", "Draw thread started")
	return threadID
}

; start the execution thread
Thread_StartExecution()
{
	; prepare variable which will be used to pass tasks or information to this thread
	_setSharedProperty("tasks.execution", object())
	
	; define thread ID
	threadID := "Execution"
	logger("t1", "Starting execution thread. ID: " threadID)

	; read source file
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Execution\execution.ahk"
	
	; replace placeholders
	StringReplace, ExecutionThreadCode, ExecutionThreadCode, % ";PlaceholderIncludesOfElements", % global_libInclusionsForThreads global_elementInclusionsForThreads

	; start the new thread
	newThread := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	
	; write thread ID to the list of all threads
	global_AllThreads[threadID] := {permanent: true, type: "Execution", thread: newThread}

	logger("t1", "Execution thread started")
	return threadID
}

; start an element thread
Thread_StartElemenThread(uniqueID, code, notifyWhenStopped)
{
	threadID := "element_" uniqueID
	logger("t1", "Starting element thread. ID: " threadID)

	newThread := AhkThread(code)
	global_AllThreads[threadID] := {permanent: true, type: "Element", thread: newThread, uniqueID: uniqueID, notifyWhenStopped: notifyWhenStopped}

	logger("t1", "Element thread started")
}


; stop an element thread
Thread_StopElemenThread(uniqueID)
{
	threadID := "element_" uniqueID
	
	logger("t1", "Stopping element thread. ID: " threadID)

	threadpars := global_AllThreads[threadID]

	; notify the element hat it should stop
	threadpars.thread.ahkFunction("ahf_exitapp")

	; prepare for killing the thread, if it does not stop itself
	settimer, Thread_KillElemenThreadIfNotStopped, -500
	threadpars.thread.kill := true
}

; kill element thread if it is not stopped
Thread_KillElemenThreadIfNotStopped()
{
	; loop through all threads
	threadsCopy := global_Allthreads.clone()
	for threadID, threadpars in threadsCopy
	{
		; check whether the thread needs to be killed
		if (threadpars.thread.kill)
		{
			; check whether the thread still runs
			if (threadpars.thread.ahkReady())
			{
				; kill the thread
				logger("t1", "Killing thread " threadID)
				threadpars.thread.ahkterminate(100)
				if (threadpars.thread.ahkReady())
				{
					logger("t0", "Killing thread " threadID " failed")
				}
			}
		}
	}
}

; stop all element threads
Thread_stopAllElementThreads()
{
	logger("t1", "Stopping all element threads")
	threadsCopy := global_Allthreads.clone()
	for threadID, threadpars in threadsCopy
	{
		; only perform on element threads
		if (threadpars.type = "element")
		{
			; check whether the thread still runs
			if (threadpars.thread.ahkReady())
			{
				; notify the element hat it should stop
				threadpars.thread.ahkFunction("ahf_exitapp")
			}
		}
	}
}

; kill all threads. This should only be called, if the threads were not able to stop themself
; there is no guarantee, that this code will properly close the threads, it may cause a crash
Thread_KillAll()
{
	logger("t1", "Killing all threads")
	threadsCopy := global_Allthreads.clone()
	
	for threadID, threadpars in threadsCopy
	{
		if (threadpars.thread.ahkReady())
		{
			logger("t1", "Killing thread " threadID)
			threadpars.thread.ahkterminate(100)
			if (threadpars.thread.ahkReady())
			{
				logger("t0", "Killing thread " threadID " failed")
			}
		}
	}
}

; called when a thread has terminated itself
Thread_Stopped(par_ThreadID)
{	
	logger("t1", "Thread  " par_ThreadID " stopped")

	; if an external thread stopped, we have to inform the execution task about it
	if (global_Allthreads[par_ThreadID].type = "element")
	{
		if (global_Allthreads[par_ThreadID].notifyWhenStopped)
		{
			API_Execution_externaElementFinish(global_Allthreads[par_ThreadID].uniqueID)
		}
	}

	; delete the thread from list
	global_Allthreads.delete(par_ThreadID)

	; check whether the thread list is empty
	for oneKey, oneValue in global_Allthreads
	{
		break
	}

	if (not oneKey)
	{
		; if thread list is empty, close the application immediately
		; the thread list can only get empty if AHF is going to close
		exitapp
	}
}

;Check whether there is already a Editor opened for that flow.
ThreadEditor_exists(p_FlowID)
{
	FoundThreadID := ""
	for oneThreadID, oneThread in global_AllThreads
	{
		if (oneThread.type = "editor")
		{
			if (oneThread.FlowID = p_FlowID)
			{
				FoundThreadID:= oneThreadID
				break
			}
		}
	}
	return (FoundThreadID != "")
}