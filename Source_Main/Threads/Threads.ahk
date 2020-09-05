global_EditorThreadIDCounter = 1
global_ExecutionThreadIDCounter = 1
global_AllThreads := CriticalObject()
global global_CommonAhkCodeForAllThreads:=""

loop, files, %_ScriptDir%\source_Elements\*.ahk, FR
{
	if not (substr(A_LoopFileName,1,1)=="_")
		global_elementInclusions .= "#include " A_LoopFileFullPath "`n"
}

Thread_init()
{
	global_CommonAhkCodeForAllThreads:="global _cs_shared := " _cs_shared "`n global _cs_execution := " _cs_execution "`n global _cs_debug := " _cs_debug "`n "
	global_CommonAhkCodeForAllThreads.="global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ") `n"

}

Thread_StartManager()
{
	global
	local ExecutionThreadCode
	local threadID
	
	_share.manager := CriticalObject()
	_share.manager.Tasks := CriticalObject()
	
	threadID := "Manager"
	logger("t1", "Starting manager thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Manager\Manager.ahk"
	;~ MsgBox %ExecutionThreadCode%
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_elementInclusions
	
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	
	global_AllThreads[threadID] := {permanent: true, type: "Manager"}
	logger("t1", "Manager thread started")
}


API_Main_StartEditor(par_FlowID) ;API Function
{
	Thread_StartEditor(par_FlowID)
}
Thread_StartEditor(par_FlowID)
{
	global
	local ExecutionThreadCode
	local threadID
	
	_share["editor" par_FlowID]:= CriticalObject()
	_share["editor" par_FlowID].Tasks := CriticalObject()
	
	threadID := "Editor" global_EditorThreadIDCounter++
	logger("t1", "Starting editor thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Editor\Editor.ahk"
	;~ MsgBox %ExecutionThreadCode%
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_elementInclusions
	
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n global FlowID := """ par_FlowID """`n"  ExecutionThreadCode)
	
	global_AllThreads[threadID] := {permanent: false, type: "Editor", flowID: par_FlowID}
	logger("t1", "Editor thread started")
}

Thread_StartDraw()
{
	global
	local ExecutionThreadCode
	local threadID
	
	_share.draw := CriticalObject()
	_share.draw.Tasks := CriticalObject()
	
	threadID := "Draw"
	logger("t1", "Starting draw thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Draw\Draw.ahk"
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	global_AllThreads[threadID] := {permanent: true, type: "Draw"}
	logger("t1", "Draw thread started")
}

Thread_StartExecution()
{
	global
	local ExecutionThreadCode
	local threadID
	
	_share.execution := CriticalObject()
	_share.execution.Tasks := CriticalObject()
	
	threadID := "Execution" global_ExecutionThreadIDCounter++
	logger("t1", "Starting execution thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Execution\execution.ahk"
	StringReplace,ExecutionThreadCode,ExecutionThreadCode, % ";PlaceholderIncludesOfElements",% global_elementInclusions
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread(global_CommonAhkCodeForAllThreads "`n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	
	global_AllThreads[threadID] := {permanent: true, type: "Execution"}
	logger("t1", "Execution thread started")
}

Thread_StopAll()
{
	global
	local threadsCopy
	local threadID
	logger("t1", "Stopping all threads")
	threadsCopy := global_Allthreads.clone()
	
	
	;~ EnterCriticalSection(_cs_shared)
	;~ EnterCriticalSection(_cs_execution)
	for threadID, threadpars in threadsCopy
	{
		;~ global_Allthreads.delete(threadID)
		if (AhkThread%threadID%.ahkReady())
		{
			;~ MsgBox terminating %threadID%
			AhkThread%threadID%.ahkterminate(-100)
			if (AhkThread%threadID%.ahkReady())
			{
				MsgBox close of thread %threadID% failed
			}
		}
	}
	;~ LeaveCriticalSection(_cs_execution)
	;~ LeaveCriticalSection(_cs_shared)
}

Thread_Stopped(par_ThreadID)
{
	global
	global_Allthreads.delete(par_ThreadID)
	logger("t1", "Thread " par_ThreadID "stopped")
	;~ d(global_Allthreads, "thread " par_ThreadID " beendet")
}