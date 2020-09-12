global global_EditorThreadIDCounter = 1
global global_AllThreads := CriticalObject()
global global_CommonAhkCodeForAllThreads:=""

loop, files, %_ScriptDir%\source_Elements\*.ahk, FR
{
	if not (substr(A_LoopFileName,1,1)=="_")
		global_elementInclusions .= "#include " A_LoopFileFullPath "`n"
}

Thread_init()
{
	global_CommonAhkCodeForAllThreads:="global _cs_shared := " _cs_shared "`n "
	global_CommonAhkCodeForAllThreads.="global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ") `n"

}

Thread_StartManager()
{
	global
	local ExecutionThreadCode
	local threadID
	
	_setSharedProperty("manager", object())
	_setSharedProperty("manager.Tasks", object())
	
	threadID := "Manager"
	logger("t1", "Starting manager thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Manager\Manager.ahk"
	;~ MsgBox %ExecutionThreadCode%
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_libInclusionsForThreads global_elementInclusionsForThreads
	
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	AhkThread%threadID%.ahkassign("_ahkThreadID",threadID)
	
	global_AllThreads[threadID] := {permanent: true, type: "Manager"}
	logger("t1", "Manager thread started")
}



Thread_StartEditor(par_FlowID)
{
	global
	local ExecutionThreadCode
	local threadID
	
	_setSharedProperty("editor" par_FlowID, object())
	_setSharedProperty("editor" par_FlowID ".Tasks", object())
	
	threadID := "Editor" global_EditorThreadIDCounter++
	logger("t1", "Starting editor thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Editor\Editor.ahk"
	;~ MsgBox %ExecutionThreadCode%
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_libInclusionsForThreads global_elementInclusionsForThreads
	
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n global FlowID := """ par_FlowID """`n"  ExecutionThreadCode)
	AhkThread%threadID%.ahkassign("_ahkThreadID",threadID)
	
	global_AllThreads[threadID] := {permanent: false, type: "Editor", flowID: par_FlowID}
	logger("t1", "Editor thread started")
}

Thread_StartDraw()
{
	global
	local ExecutionThreadCode
	local threadID
	
	_setSharedProperty("draw", object())
	_setSharedProperty("draw.Tasks", object())
	
	threadID := "Draw"
	logger("t1", "Starting draw thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Draw\Draw.ahk"
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	AhkThread%threadID%.ahkassign("_ahkThreadID",threadID)

	global_AllThreads[threadID] := {permanent: true, type: "Draw"}
	logger("t1", "Draw thread started")
}

Thread_StartExecution()
{
	global
	local ExecutionThreadCode
	local threadID
	
	_setSharedProperty("execution", object())
	_setSharedProperty("execution.Tasks", object())
	
	threadID := "Execution"
	logger("t1", "Starting execution thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Execution\execution.ahk"
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_elementInclusions
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	AhkThread%threadID%.ahkassign("_ahkThreadID",threadID)
	
	global_AllThreads[threadID] := {permanent: true, type: "Execution"}
	logger("t1", "Execution thread started")
}

; stop all threads. This should only be called, if the threads were not able to stop themself
; there is no guarantee, that this code will properly close the threads, it may cause a crash
Thread_StopAll()
{
	global
	local threadsCopy
	local threadID
	logger("t1", "Stopping all threads")
	threadsCopy := global_Allthreads.clone()
	
	for threadID, threadpars in threadsCopy
	{
		;~ global_Allthreads.delete(threadID)
		if (AhkThread%threadID%.ahkReady())
		{
			logger("t1", "Killing thread " threadID)
			AhkThread%threadID%.ahkterminate(100)
			if (AhkThread%threadID%.ahkReady())
			{
				logger("t0", "Killing thread " threadID " failed")
			}
		}
	}
}

; Terminates a thread wich requested the main thread to terminate it
Thread_Stopped(par_ThreadID)
{
	global
	; delete the thread from list
	global_Allthreads.delete(par_ThreadID)

	; terminate thread
	AhkThread%par_ThreadID%.ahkterminate(100)
	logger("t1", "Thread " par_ThreadID "stopped")
	
	; check whether the thread list is empty
	local oneKey, oneValue
	for oneKey, oneValue in global_Allthreads
	{
		break
	}

	if (not oneKey)
	{
		; if thread list is empty, close the application immetiately
		; the thread list can only get empty if AHF is going to close
		exitapp
	}
}