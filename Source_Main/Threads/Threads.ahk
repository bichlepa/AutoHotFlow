global_EditorThreadIDCounter = 1
global_ExecutionThreadIDCounter = 1
global_AllThreads := CriticalObject()
_ahkCriticalSectionExecution := CriticalSection()
global_CriticalSectionGlobalVars := CriticalSection()


;~ global_elementInclusions := "`n"
loop, files, %_ScriptDir%\source_Elements\*.ahk, FR
{
	if not (substr(A_LoopFileName,1,1)=="_")
		global_elementInclusions .= "#include " A_LoopFileFullPath "`n"
}

Thread_StartManager()
{
	global
	local ExecutionThreadCode
	local threadID
	
	
	threadID := "Manager"
	logger("t1", "Starting manager thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Manager\Manager.ahk"
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread("global _ahkCriticalSection_Flows := CriticalSection("_ahkCriticalSection_Flows ")`n global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ") `n global _ahkThreadID := """ threadID """`n" ExecutionThreadCode)
	
	global_AllThreads[threadID] := {permanent: true, type: "Manager"}
	logger("t1", "Manager thread started")
}


Thread_StoppAll()
{
	global
	local threadsCopy
	logger("t1", "Stopping all threads")
	threadsCopy := global_Allthreads.clone()
	for threadID, threadpars in threadsCopy
	{
		global_Allthreads.delete(threadID)
		if (AhkThread%threadID%.ahkReady())
			AhkThread%threadID%.ahkterminate(-1)
	}
}

Thread_StartEditor(par_FlowID)
{
	global
	local ExecutionThreadCode
	local threadID
	threadID := "Editor" global_EditorThreadIDCounter++
	logger("t1", "Starting editor thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Editor\Editor.ahk"
	;~ MsgBox %ExecutionThreadCode%
	StringReplace,ExecutionThreadCode,ExecutionThreadCode,;PlaceholderIncludesOfElements,% global_elementInclusions
	
	AhkThread%threadID% := AhkThread("global _ahkCriticalSection_Flows := CriticalSection("_ahkCriticalSection_Flows ")`n global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ") `n global _ahkThreadID := """ threadID """`n global FlowID := """ par_FlowID """`n"  ExecutionThreadCode)
	
	global_AllThreads[threadID] := {permanent: false, type: "Editor", flowID: par_FlowID}
	logger("t1", "Editor thread started")
}

Thread_StartDraw()
{
	global
	local ExecutionThreadCode
	local threadID
	threadID := "Draw"
	logger("t1", "Starting draw thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Draw\Draw.ahk"
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread("global _ahkCriticalSection_Flows := CriticalSection("_ahkCriticalSection_Flows ")`n global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ") `n global _ahkThreadID = " threadID "`n" ExecutionThreadCode)
	global_AllThreads[threadID] := {permanent: true, type: "Draw"}
	logger("t1", "Draw thread started")
}

Thread_StartExecution()
{
	global
	local ExecutionThreadCode
	local threadID
	threadID := "Execution" global_ExecutionThreadIDCounter++
	logger("t1", "Starting execution thread. ID: " threadID)
	FileRead,ExecutionThreadCode,% _ScriptDir "\Source_Execution\execution.ahk"
	StringReplace,ExecutionThreadCode,ExecutionThreadCode,;PlaceholderIncludesOfElements,% global_elementInclusions
	;~ MsgBox %ExecutionThreadCode%
	AhkThread%threadID% := AhkThread("global _ahkCriticalSection_Flows := CriticalSection("_ahkCriticalSection_Flows ")`n global _flows := CriticalObject(" (&_flows) ") `n global _settings := CriticalObject(" (&_settings) ") `n global _execution := CriticalObject(" (&_execution) ") `n global _share := CriticalObject(" (&_share) ")`n global _language := CriticalObject(" (&_language) ")`n global _ahkThreadID = " threadID "`n" ExecutionThreadCode)
	
	global_AllThreads[threadID] := {permanent: true, type: "Execution"}
	logger("t1", "Execution thread started")
}

Thread_Stopped(par_ThreadID)
{
	global
	global_Allthreads.delete(par_ThreadID)
	logger("t1", "Thread " par_ThreadID "stopped")
	;~ d(global_Allthreads, "thread " par_ThreadID " beendet")
}