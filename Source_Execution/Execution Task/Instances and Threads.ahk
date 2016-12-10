InstanceIDCOunter:=0
ThreadIDCOunter:=0


/* Starts a new execution instance
*/
newInstance(p_Environment)
{
	global _execution, InstanceIDCOunter, _flows
	if (_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy="skip" or _flows[p_Environment.FlowID].flowSettings.ExecutionPolicy="stop")
	{
		;find out whether the flow is running
		if (_flows[p_Environment.FlowID].executing)
		{
			if (_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy="skip")
			{
				logger("f1", "Execution of flow '" _flows[p_Environment.FlowID].name "' skipped, due to flow execution policy")
				return
				
			}
			else if (_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy="stop")
			{
				logger("f1", "Stopping flow '" _flows[p_Environment.FlowID].name "' in order to relaunch it, due to flow execution policy")
				stopFlow(_flows[p_Environment.FlowID])
			}
		}
	}
	
	;Search for the matching trigger element
	for oneElementID, oneElement in _flows[p_Environment.flowID].allElements
	{
		;~ MsgBox % (oneElement.type = "trigger") " - " !(p_Environment.ElementID) " - " (p_Environment.ElementID=oneElement.id) " = " (oneElement.type = "trigger" and (!(p_Environment.ElementID) or p_Environment.ElementID=oneElement.id))
		if (oneElement.type = "trigger" and (!(p_Environment.ElementID) or p_Environment.ElementID=oneElement.id))
		{
			newInstance:=CriticalObject()
			newInstance.id:= "instance" ++InstanceIDCOunter
			newInstance.FlowID := p_Environment.FlowID
			newInstance.state := "init"
			newInstance.InstanceVars := CriticalObject()
			newThread := newThread(newInstance)
			_execution.Instances[newInstance.id]:=newInstance
			newThread.ElementID := oneElementID
			newThread.EnvironmentType := "thread"
			finishExecutionOfElement(newThread, "Normal")
			ThreadVariable_Set(newThread,"A_TriggerTime",a_now,"Date")
			
			ElementClass:=p_Environment.ElementClass
			if (isfunc("Element_postTrigger_" ElementClass))
			{
				Element_postTrigger_%ElementClass%(newThread, p_Environment.pars)
			}
			
			newInstance.state := "running"
			break
		}
	}
	
	updateFlowExcutingStates()
	return newInstance
}

stopFlow(p_Flow)
{
	global _execution, _flows
	
	instancesToDelete:=Object()
	
	for OneInstanceID, OneInstance in _execution.Instances
	{
		if (OneInstance.FlowID == p_Flow.id)
		{
			instancesToDelete.push(OneInstanceID)
			for OneThreadID, OneThread in OneInstance.threads
			{
				OneThread.oldstate := OneThread.state
				OneThread.state := "stopping"
			}
		}
	}
	for OneInstanceIndex, OneInstanceID in instancesToDelete
	{
		for OneThreadID, OneThread in _execution.Instances[OneInstanceID].threads
		{
			if (OneThread.oldstate = "running" )
			{
				oneElement:=_flows[OneThread.flowID].allElements[OneThread.elementID]
				oneElementClass:=oneElement.class
				oneElement.countRuns--
				if (oneElement.countRuns = 0)
				oneElement.state:="finished"
				oneElement.lastrun:=a_tickcount
					
				if Isfunc("Element_stop_" oneElementClass )
						Element_stop_%oneElementClass%(OneThread, OneThread.elementpars)
				
				_flows[OneThread.flowID].draw.mustDraw:=true
			}
		}
		_execution.Instances.delete(OneInstanceID)
	}
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
		newThread.ThreadID := newThread.id
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
	updateFlowExcutingStates()
}

updateFlowExcutingStates()
{
	global _execution, _flows
	
	executingFlows:=Object()
	for OneInstanceID, OneInstance in _execution.Instances
	{
		executingFlows[OneInstance.flowID]:=True
	}
	for OneFlowID, OneFlow in _flows
	{
		if (executingFlows.haskey(OneFlowID))
		{
			OneFlow.executing:=True
		}
		else
		{
			OneFlow.executing:=False
		}
	}
}