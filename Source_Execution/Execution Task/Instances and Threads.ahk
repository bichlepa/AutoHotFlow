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
	oneElementID:=p_Environment.elementID
	if oneElementID=
	{
		MsgBox Internal Error in newInstance(): trigger element ID unknown
		return
	}
	
	newInstance:=CriticalObject()
	newInstance.id:= "instance" ++InstanceIDCOunter
	newInstance.FlowID := p_Environment.FlowID
	newInstance.state := "init"
	newInstance.InstanceVars := CriticalObject()
	newInstance.InstanceVarsHidden := CriticalObject()
	newThread := newThread(newInstance)
	_execution.Instances[newInstance.id]:=newInstance
	newThread.ElementID := oneElementID
	newThread.EnvironmentType := "thread"
	finishExecutionOfElement(newThread, "Normal")
	ThreadVariable_Set(newThread,"A_TriggerTime",a_now)
	
	if (p_Environment.params.varstoPass)
	{
		;~ d(p_Environment.params.varstoPass, "ioöhöio")
		for onevarName, oneVar in p_Environment.params.varstoPass
		{
			InstanceVariable_Set(newThread, onevarName, oneVar)
		}
	}
	
	if (p_Environment.params.CallBack)
	{
		newInstance.callBack := p_Environment.params.CallBack
	}
	
	ElementClass:=p_Environment.ElementClass
	if (isfunc("Element_postTrigger_" ElementClass))
	{
		Element_postTrigger_%ElementClass%(newThread, p_Environment.pars)
	}
	newInstance.state := "running"
	
	updateFlowExcutingStates()
	return newInstance
}

/**
Start all manual triggers
*/
startFlow(p_Flow, p_Trigger ="", p_params = "")
{
	static
	global _flows
	local TriggerFound:=false
	;If not trigger assigned, trigger the default manual trigger (if any)
	if (p_Trigger="")
	{
		for oneElementID, oneElement in p_Flow.allElements
		{
			if (oneElement.class = "trigger_manual" and oneElement.defaultTrigger = True)
			{
				p_Trigger := oneElement
				TriggerFound:=True
			}
			
		}
		if not TriggerFound
		{
			gui,hintThatNoManualTriggerAvailable:destroy
			gui,hintThatNoManualTriggerAvailable:add, text, w200 , % lang("There is no manual trigger available")
			gui,hintThatNoManualTriggerAvailable:add, button, default w100 x50 Y+10 h30 ghintThatNoManualTriggerAvailableGuiClose , % lang("OK")
			gui,hintThatNoManualTriggerAvailable:show,,AutoHotFlow
			return
		}
	}
	;~ d(p_Trigger)
	environment:=Object()
	environment.flowID:=p_Flow.id
	environment.elementID:=p_Trigger.id
	environment.params:=p_params
	newInstance(environment)
	
	
	return
	
	hintThatNoManualTriggerAvailableGuiClose:
	
	gui,hintThatNoManualTriggerAvailable:destroy
	return
}

stopFlow(p_Flow)
{
	global _execution, _flows
	
	instancesToDelete:=Object()
	
	for OneInstanceID, OneInstance in _execution.Instances
	{
		if (OneInstance.FlowID == p_Flow.id)
		{
			stopInstance(OneInstance)
		}
	}
}

stopInstance(p_instance)
{
	global _execution, _flows
	
	for OneThreadID, OneThread in p_instance.threads
	{
		OneThread.oldstate := OneThread.state
		OneThread.state := "stopping"
	}
	
	for OneThreadID, OneThread in p_instance.threads
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
	
	
	if (p_instance.callback)
	{
		tempCallBackfunc:=p_instance.callback
		%tempCallBackfunc%("stopped", p_instance.InstanceVars)
	}
	
	_execution.Instances.delete(p_instance.id)
	
	updateFlowExcutingStates()
}


executeToggleFlow(p_Flow)
{
	;~ d(p_Flow)
	if (p_Flow.executing)
	{
		stopFlow(p_Flow)
	}
	else
	{
		startFlow(p_Flow)
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
		newThread.threadVarsHidden := CriticalObject()
		newThread.loopVars := CriticalObject()
		newThread.loopVarsHidden := CriticalObject()
		newThread.loopVarsStack := CriticalObject()
		newThread.loopVarsStackHidden := CriticalObject()
		
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
	local tempCallBackfunc
	;~ d(_execution, "going to remove " p_instance.id)
	
	if (p_instance.callback)
	{
		tempCallBackfunc:=p_instance.callback
		%tempCallBackfunc%("finished", objfullyclone(p_instance.InstanceVars))
	}
	
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