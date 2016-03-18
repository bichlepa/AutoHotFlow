

globalinstancecounter=0
globalthreadcounter=0
allInstances:=CriticalObject()
allThreads:=CriticalObject()

Instance_New()
{
	global globalinstancecounter
	global allInstances
	newInstance:=CriticalObject()
	newInstance.state:="stopped"
	newInstance.vars:=[]
	newInstance.threads:=[]
	newInstance.ID:="instance" . format("{1:010u}",++globalinstancecounter)
	newInstance.Trigger:=""
	
	;Create new thread
	NewThreadID:=Thread_New(newInstance.id)
	newInstance.threads[NewThreadID]:=NewThreadID
	newInstance.firstThread:=NewThreadID
	ThreadVariable_Set(NewThreadID,"a_triggertime",a_now,"Date")
	
	;Add to global list
	allInstances[newInstance.ID]:=newInstance
	return newInstance.ID
}


Thread_New(p_InstanceID)
{
	global globalinstancecounter
	global allThreads
	
	newThread:=CriticalObject()
	newThread.state:="stopped"
	newThread.vars:=[]
	newThread.loopvars:=[]
	newThread.Instance:=p_InstanceID
	newThread.ID:="thread" . format("{1:010u}",++globalthreadcounter)
	
	;Add to global list
	allThreads[newThread.ID]:=newThread
	return newThread.ID
}

Instance_Remove(p_ID)
{
	global allInstances
	allInstances.delete(p_ID)
}

Thread_Remove(p_ID)
{
	global allThreads
	allThreads.delete(p_ID)
}

Instance_Stop(p_ID)
{
	global allInstances
	allInstances[p_ID].state:="stopping"
	for forID, forID2 in allInstances[p_ID].threads
	{
		Thread_Stop(forID)
	}
}

Thread_Stop(p_ID)
{
	global allThreads
	allThreads[p_ID].state:="stopping"
	;TODO: Tell the execution thread that it should stop
}

Instance_StopAll()
{
	for forID, forInstance in allInstances
	{
		Instance_Stop(forID)
	}
}

Thread_Clone(p_ID)
{
	newThread:=CriticalObject()
	for forID, forValue in allThreads[p_ID]
	{
		if IsObject(forValue)
		{
			newThread[forID]:=forValue.clone()
		}
		else
			newThread[forID]:=forValue
	}
	
	newThread.ID:="thread" . format("{1:010u}",++globalthreadcounter)
	
	;Add to global list
	allThreads[newThread.ID]:=newThread
	
}
