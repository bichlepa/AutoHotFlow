global global_InstanceIDCOunter:=0
global global_ThreadIDCOunter:=0

/* Starts a new execution instance
*/
newInstance(p_Environment, p_params = "")
{
	_EnterCriticalSection()

	executing := _getFlowProperty(p_Environment.FlowID, "executing")


	;find out whether the flow is running
	if (executing)
	{
		ExecutionPolicy := _getFlowProperty(p_Environment.FlowID, "flowSettings.ExecutionPolicy")
		if (ExecutionPolicy = "default")
			ExecutionPolicy:=_getSettings("FlowExecutionPolicy")

		if (ExecutionPolicy="skip")
		{
			logger("f1", "Execution of flow '" _getFlowProperty(p_Environment.FlowID, "name") "' skipped, due to flow execution policy")
			skipped := true
			
		}
		else if (ExecutionPolicy="stop")
		{
			logger("f1", "Stopping flow '" _getFlowProperty(p_Environment.FlowID, "name") "' in order to relaunch it, due to flow execution policy")
			stopFlow(p_Environment.FlowID)
		}
	}
	
	if (not skipped)
	{
		;Search for the matching trigger element
		oneElementID:=p_Environment.elementID
		if oneElementID=
		{
			MsgBox Internal Error in newInstance(): trigger element ID unknown
		}
		else
		{
			
			newInstance:=Object()
			newInstanceId := "instance" ++global_InstanceIDCOunter
			newInstance.id:= newInstanceId
			newInstance.FlowID := p_Environment.FlowID
			newInstance.FlowName :=  _getFlowProperty(p_Environment.FlowID, "name")
			newInstance.state := "running"
			newInstance.InstanceVars := Object()
			newInstance.InstanceVarsHidden := Object()
			_setInstance(newInstanceId, newInstance)

			if (p_params.CallBack)
			{
				_setInstanceProperty(newInstanceId, "CallBack", p_params.CallBack, false)
			}
			

			newThreadID := newThread(newInstanceId)
			_setThreadProperty(newInstanceId, newThreadID, "ElementID", oneElementID)
			if (p_Environment.threadID)
			{
				; The previous thread may have some information which we want to import to the new thread
				varsExportedFromExternalThread := _getThreadProperty(p_Environment.InstanceId, p_Environment.ThreadID, "varsExportedFromExternalThread")
				_setThreadProperty(newInstanceId, newThreadID, "varsExportedFromExternalThread", varsExportedFromExternalThread)
				
				varstoPass := _getThreadProperty(p_Environment.InstanceId, p_Environment.ThreadID, "params.varstoPass")
				if (varstoPass)
				{
					for onevarName, oneVar in varstoPass
					{
						InstanceVariable_Set(newThread, onevarName, oneVar)
					}
				}
			}
			finishExecutionOfElement(newInstanceId, newThreadID, "Normal")
			ThreadVariable_Set(newThreadID, "A_TriggerTime", a_now)
			
			
			ElementClass:=_getElementProperty(p_Environment.FlowID, p_Environment.ElementID, "class")
			if (isfunc("Element_postTrigger_" ElementClass))
			{
				Element_postTrigger_%ElementClass%(newThread, p_params)
			}
			
			updateFlowExcutingStates()
		}
	}
	_LeaveCriticalSection()
	return newInstance
}

/**
Start execution of the flow
; todo: descriobe p_params
*/
ExecuteFlow(p_FlowID, p_TriggerID ="", p_params = "")
{
	static

	_EnterCriticalSection()

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
		environment.elementID:=p_TriggerID
		newInstance(environment, p_params)
	}
	
	_LeaveCriticalSection()
	
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

stopFlow(p_FlowID)
{
	_EnterCriticalSection()
	
	InstanceIDs := _getAllInstanceIds()
	for OneInstanceIndex, OneInstanceID in InstanceIDs
	{
		if (_getInstanceProperty(OneInstanceID, "FlowID") == p_FlowID)
		{
			stopInstance(OneInstanceID)
		}
	}
	_LeaveCriticalSection()
}

stopInstance(p_instanceID)
{
	_EnterCriticalSection()

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
	
	_LeaveCriticalSection()
}


executeToggleFlow(p_FlowID)
{
	_EnterCriticalSection()

	if (_getFlowProperty(FlowID, "executing"))
	{
		stopFlow(p_FlowID)
	}
	else
	{
		ExecuteFlow(p_FlowID)
	}
	
	_LeaveCriticalSection()
}

/* Starts a new execution thread inside the given instance
if p_ToCloneFromThread is given, the thread will be cloned
*/
newThread(p_InstanceID, p_ToCloneFromThreadID ="")
{
	_EnterCriticalSection()

	if (p_ToCloneFromThreadID)
	{
		;Do a clone of the thread
		newThread := _getThread(p_InstanceID, p_ToCloneFromThreadID)
		;Assign another thread id
		newThread.id := "thread" ++global_ThreadIDCOunter
		newThread.ThreadID := newThread.id
	}
	else
	{
		;Create a new thread which starts at the trigger
		newThread := Object()
		newThread.id := "thread" ++global_ThreadIDCOunter
		newThread.ThreadID := newThread.id
		newThread.InstanceID :=p_InstanceID
		newThread.FlowID := _getInstanceProperty(p_InstanceID, "FlowID")
		newThread.State := "finished" ;This means, the execution of the trigger has finished
		
		newThread.ElementPars := Object()
		newThread.Result := "Normal"
		newThread.threadVars := Object()
		newThread.threadVarsHidden := Object()
		newThread.loopVars := Object()
		newThread.loopVarsHidden := Object()
		newThread.loopVarsStack := Object()
		newThread.loopVarsStackHidden := Object()
		
		;~ newThread.ElementID ; Will not be set in this function
	}
	
	_setThread(p_InstanceID, newThread.id, newThread)

	_LeaveCriticalSection()
	return newThread.ID
}

removeThread(p_instanceID, p_threadID)
{
	global 
	_EnterCriticalSection()

	_deleteThread(p_instanceID, p_threadID)
	if (_getAllThreadIds(p_instanceID).count() = 0)
	{
		removeInstance(p_instanceID)
	}
	_LeaveCriticalSection()
}

removeInstance(p_instanceID)
{
	global
	local tempCallBackfunc
	_EnterCriticalSection()
	tempCallBackfunc := _getInstanceProperty(p_InstanceID, "callback", false)
	if (tempCallBackfunc)
	{
		%tempCallBackfunc%("finished", _getInstanceProperty(p_InstanceID, "InstanceVars"))
	}
	
	_deleteInstance(p_instanceID)
	updateFlowExcutingStates()

	_LeaveCriticalSection()
}

updateFlowExcutingStates()
{
	_EnterCriticalSection()

	executingFlows:=Object()
	Instances := _getAllInstanceIds()
	for OneInstanceIndex, OneInstanceID in Instances
	{
		executingFlows[_getInstanceProperty(OneInstanceID, "flowID")]:=True
	}
	Flows := _getAllFlowIds()
	for OneFlowIndex, OneFlowID in Flows
	{
		if (executingFlows.haskey(OneFlowID))
		{
			_setFlowProperty(OneFlowID, "executing", True)
		}
		else
		{
			_setFlowProperty(OneFlowID, "executing", False)
		}
	}

	_LeaveCriticalSection()
}