InstanceIDCOunter:=0
ThreadIDCOunter:=0


/* Starts a new execution instance
*/
newInstance(p_Flow)
{
	global _execution, InstanceIDCOunter
	;Search for the matching trigger element
	for oneElementID, oneElement in p_Flow.allElements
	{
		if (oneElement.type = "trigger")
		{
			newInstance:=CriticalObject()
			newInstance.id:= "instance" ++InstanceIDCOunter
			newInstance.FlowID := p_Flow.id
			newInstance.InstanceVars := CriticalObject()
			newInstance.InstanceVars := CriticalObject()
			newThread := newThread(newInstance)
			_execution.Instances[newInstance.id]:=newInstance
			newThread.ElementID := oneElementID
		}
	}
	return newInstance
}

/* Starts a new execution thread inside the given instance
if p_ToCloneFromThread is given, the thread will be cloned
*/
newThread(p_Instance, p_ToCloneFromThread ="")
{
	global ThreadIDCOunter
	if IsObject(p_ToCloneFromThread)
	{
		;Do a clone of the thread
		newThread := objfullyclone(p_ToCloneFromThread)
		;Assign another thread id
		newThread.id := "thread" ++ThreadIDCOunter
	}
	else
	{
		;Create a new thread which starts at the trigger
		newThread := CriticalObject()
		newThread.id := "thread" ++ThreadIDCOunter
		newThread.ThreadID := newThread.id
		newThread.InstanceID := p_Instance.id
		newThread.FlowID := p_Instance.FlowID
		newThread.State := "finished" ;This means, the execution of the trigger has finished
		
		newThread.ElementPars := CriticalObject()
		newThread.Result := "Normal"
		newThread.threadVars := CriticalObject()
		newThread.loopVars := CriticalObject()
		
		;~ newThread.ElementID ; Will not be set in this function
	}
	
	p_Instance.threads[newThread.id]:=newThread
	return newThread
}

removeThread(p_thread)
{
	global 
	;~ d(_execution.Instances[p_thread.Instanceid], "going to remove " p_thread.id)
	_execution.Instances[p_thread.Instanceid].threads.delete(p_thread.id)
	if (_execution.Instances[p_thread.Instanceid].threads.count() = 0)
	{
		removeInstance(_execution.Instances[p_thread.Instanceid])
	}
	;~ d(_execution.Instances[p_thread.Instanceid], "removed " p_thread.id)
}

removeInstance(p_instance)
{
	global
	;~ d(_execution, "going to remove " p_instance.id)
	_execution.Instances.delete(p_instance.id)
	;~ d(_execution, "removed " p_instance.id)
}