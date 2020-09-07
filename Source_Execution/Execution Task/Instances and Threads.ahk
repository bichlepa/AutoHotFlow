global global_InstanceIDCOunter:=0
global global_ThreadIDCOunter:=0

/* Starts a new execution instance
*/
newInstance(p_Environment)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	if (_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy="skip" or _flows[p_Environment.FlowID].flowSettings.ExecutionPolicy="stop")
	{
		;find out whether the flow is running
		if (_flows[p_Environment.FlowID].executing)
		{
			if (_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy = "default")
				ExecutionPolicy:=_settings.FlowExecutionPolicy
			else
				ExecutionPolicy:=_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy
			if (ExecutionPolicy="skip")
			{
				logger("f1", "Execution of flow '" _flows[p_Environment.FlowID].name "' skipped, due to flow execution policy")
				return
				
			}
			else if (ExecutionPolicy="stop")
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
	}
	else
	{
		
		newInstance:=CriticalObject()
		newInstance.id:= "instance" ++global_InstanceIDCOunter
		newInstance.FlowID := p_Environment.FlowID
		newInstance.FlowName := p_Environment.FlowName
		newInstance.state := "init"
		newInstance.InstanceVars := CriticalObject()
		newInstance.InstanceVarsHidden := CriticalObject()
		newThread := newThread(newInstance)
		_execution.Instances[newInstance.id]:=newInstance
		newThread.ElementID := oneElementID
		newThread.EnvironmentType := "thread"
		newThread.varsExportedFromExternalThread := p_Environment.varsExportedFromExternalThread
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
	}
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
	return newInstance
}

/**
Start all manual triggers
*/
startFlow(p_FlowID, p_TriggerID ="", p_params = "")
{
	static

	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	;If not trigger assigned, trigger the default manual trigger (if any)
	if (p_TriggerID="")
	{
		allElementIDs := _getAllElementIds(p_FlowID)
		for forelementIndex, forelementID in allElementIDs
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_Manual" and _getElementProperty(p_FlowID, forelementID, "defaultTrigger") = True)
			{
				p_TriggerID := forelementID
			}
			
		}
	}
	if (p_TriggerID)
	{
		environment:=Object()
		environment.flowID:=p_FlowID
		environment.FlowName:=_getFlowProperty(p_FlowID, "Name") ; todo: löschen
		environment.elementID:=p_TriggerID
		environment.params:=p_params
		newInstance(environment)
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
	
	if not p_TriggerID
	{
		gui,hintThatNoManualTriggerAvailable:destroy
		gui,hintThatNoManualTriggerAvailable:add, text, w200 , % lang("There is no default manual trigger available")
		gui,hintThatNoManualTriggerAvailable:add, button, default w100 x50 Y+10 h30 ghintThatNoManualTriggerAvailableGuiClose , % lang("OK")
		gui,hintThatNoManualTriggerAvailable:show,,AutoHotFlow
	}	
	return
	
	hintThatNoManualTriggerAvailableGuiClose:
	
	gui,hintThatNoManualTriggerAvailable:destroy
	return
}

stopFlow(p_Flow)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	instancesToDelete:=Object()
	
	for OneInstanceID, OneInstance in _execution.Instances
	{
		if (OneInstance.FlowID == p_Flow.id)
		{
			stopInstance(OneInstance.ID)
		}
	}
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

stopInstance(p_instanceID)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	instance := _getInstance(p_instanceID)
	for OneThreadID, OneThread in instance.threads
	{
		; Werte auch in der lokalen Kopie setzen, weil wir damit weiterarbeiten
		OneThread.oldstate := OneThread.state
		OneThread.state := "stopping"
		_setThreadProperty(p_instanceID, OneThreadID, "oldstate", OneThread.oldstate)
		_setThreadProperty(p_instanceID, OneThreadID, "state", OneThread.state)
	}
	
	for OneThreadID, OneThread in instance.threads
	{
		if (OneThread.oldstate = "running" )
		{
			oneElement:=_flows[OneThread.flowID].allElements[OneThread.elementID]
			oneElementClass:=_getElementProperty(OneThread.FlowID, OneThread.ElementID, "class")
			oneElementCountRuns := _getAndIncrementElementProperty(OneThread.FlowID, OneThread.ElementID, "countRuns", -1)
			if (oneElementCountRuns = 0)
				_setElementProperty(OneThread.FlowID, OneThread.ElementID, "state", "finished")
			_setElementProperty(OneThread.FlowID, OneThread.ElementID, "lastrun", a_tickcount)
			
			global_AllExecutionIDs.delete(OneThread.uniqueID)
			
			if Isfunc("Element_stop_" oneElementClass )
				Element_stop_%oneElementClass%({FlowID: OneThread.FlowID, ElementID: OneThread.ElementID, InstanceID: OneThread.InstanceID, ThreadID: OneThread.ID}, OneThread.elementpars)
			
			_setFlowProperty(OneThread.flowID, "draw.mustDraw", true)
		}
	}
	
	if (instance.callback)
	{
		tempCallBackfunc := instance.callback
		%tempCallBackfunc%("stopped", instance.InstanceVars)
	}
	
	_deleteInstance(p_instanceID)
	
	updateFlowExcutingStates()
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}


executeToggleFlow(p_Flow)
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	if (p_Flow.executing)
	{
		stopFlow(p_Flow)
	}
	else
	{
		startFlow(p_Flow.ID)
	}
	
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

/* Starts a new execution thread inside the given instance
if p_ToCloneFromThread is given, the thread will be cloned
*/
newThread(p_Instance, p_ToCloneFromThread ="")
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	if IsObject(p_ToCloneFromThread)
	{
		;Do a clone of the thread
		newThread := objfullyclone(p_ToCloneFromThread)
		;Assign another thread id
		newThread.id := "thread" ++global_ThreadIDCOunter
		newThread.ThreadID := newThread.id
	}
	else
	{
		;Create a new thread which starts at the trigger
		newThread := CriticalObject()
		newThread.id := "thread" ++global_ThreadIDCOunter
		newThread.ThreadID := newThread.id
		newThread.InstanceID := p_Instance.id
		newThread.FlowID := p_Instance.FlowID
		newThread.FlowName := p_Instance.FlowName
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

	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
	return newThread
}

removeThread(p_thread)
{
	global 
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

	_execution.Instances[p_thread.Instanceid].threads.delete(p_thread.id)
	if (_execution.Instances[p_thread.Instanceid].threads.count() = 0)
	{
		removeInstance(_execution.Instances[p_thread.Instanceid])
	}
	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

removeInstance(p_instance)
{
	global
	local tempCallBackfunc
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)
	
	if (p_instance.callback)
	{
		tempCallBackfunc:=p_instance.callback
		%tempCallBackfunc%("finished", objfullyclone(p_instance.InstanceVars))
	}
	
	_execution.Instances.delete(p_instance.id)
	updateFlowExcutingStates()

	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}

updateFlowExcutingStates()
{
	EnterCriticalSection(_cs_shared)
	EnterCriticalSection(_cs_execution)

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

	LeaveCriticalSection(_cs_execution)
	LeaveCriticalSection(_cs_shared)
}