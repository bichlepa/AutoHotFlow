global global_InstanceIdCounter := 0
global global_ThreadIdCounter := 0

; Starts a new execution instance
; p_Environment: Environment data like Flow ID and element ID
; p_instanceVars: list of instance variables which should be set at the beginning
; p_instanceProperties: instance properties, which will be set
; p_dataForPostTrigger: data which will be passed to the Element_postTrigger_...() function 
newInstance(p_Environment, p_instanceVars = "", p_instanceProperties = "", p_dataForPostTrigger = "")
{
	_EnterCriticalSection()

	;find out whether the flow is running
	executing := _getFlowProperty(p_Environment.FlowID, "executing")
	if (executing)
	{
		; the flow is currently running. We need to theck the execution policy settings
		ExecutionPolicy := _getFlowProperty(p_Environment.FlowID, "flowSettings.ExecutionPolicy")
		if (ExecutionPolicy = "default")
		{
			ExecutionPolicy := _getSettings("FlowExecutionPolicy")
		}

		; decide what to do, depending on the execution policy
		if (ExecutionPolicy = "skip")
		{
			; we will skip the current instance (effencively ignore this call)
			logger("f1", "Execution of flow '" _getFlowProperty(p_Environment.FlowID, "name") "' skipped, due to flow execution policy")
			skipped := true
			
		}
		else if (ExecutionPolicy = "stop")
		{
			; we will stop the current instance and start a new one
			logger("f1", "Stopping flow '" _getFlowProperty(p_Environment.FlowID, "name") "' in order to relaunch it, due to flow execution policy")
			stopFlow(p_Environment.FlowID)
		}
		Else
		{
			; we will start a new one
		}
	}
	
	if (not skipped)
	{
		;Search for the matching trigger element
		oneElementID := p_Environment.elementID
		if not oneElementID
		{
			throw exception("trigger element ID unknown: " oneElementID, -1)
		}
		else
		{
			; create a new instance
			newInstance := Object()
			newInstanceId := "instance" ++global_InstanceIdCounter
			newInstance.id := newInstanceId
			newInstance.InstanceID := newInstanceId
			newInstance.FlowID := p_Environment.FlowID
			newInstance.state := "running"
			newInstance.InstanceVars := Object()
			newInstance.InstanceVarsHidden := Object()
			_setInstance(newInstanceId, newInstance)
			
			; create a first thread
			newThreadID := newThread(newInstanceId)
			_setThreadProperty(newInstanceId, newThreadID, "ElementID", oneElementID)
			
			; We may need to import some instance variables
			if (p_instanceVars)
			{
				for onevarName, oneValue in p_instanceVars
				{
					InstanceVariable_Set({instanceID: newInstanceId, threadID: newThreadID}, onevarName, oneValue)
				}
			}
			
			; We may need to import some variables
			if (p_instanceProperties)
			{
				for onevarName, oneValue in p_instanceProperties
				{
					_setInstanceProperty(newInstanceId, onevarName, oneValue, false)
				}
			}
			
			; to start the execution of elements which are connected to the trigger, we will reuse code which is executed when an element finishes it execution.
			finishExecutionOfElement(newInstanceId, newThreadID, "Normal")

			; set some thread variable with informations about the trigger event
			ThreadVariable_Set({instanceID: newInstanceId, threadID: newThreadID}, "A_TriggerTime", a_now)
			ThreadVariable_Set({instanceID: newInstanceId, threadID: newThreadID}, "A_TriggerID", p_Environment.ElementID)
			
			; some triggers have functions which must be called after a thread has started.
			; it is usually used to set some thread variables which contain some additional informations of the trigger event
			ElementClass := _getElementProperty(p_Environment.FlowID, p_Environment.ElementID, "class")
			if (isfunc("Element_postTrigger_" ElementClass))
			{
				elementParams := _getElementProperty(p_Environment.FlowID, p_Environment.ElementID, "pars")
				Element_postTrigger_%ElementClass%({instanceID: newInstanceId, threadID: newThreadID}, elementParams, p_dataForPostTrigger)
			}
			
			; updates the "executing" property of the flow
			updateFlowExcutingStates()
		}
	}
	Else
	{
		; it is possible that a funtion will be called a soon as the instance stops. If so, we will call the callback to in form the waiting function that the instance won't be executed.
		tempCallBackfunc := _getInstanceProperty(p_InstanceID, "callback", false)
		if (tempCallBackfunc)
		{
			%tempCallBackfunc%("skipped", [])
		}
	}
	_LeaveCriticalSection()

	return newInstanceId
}


; Start execution of the flow
; todo: descriobe p_params
ExecuteFlow(p_FlowID, p_TriggerID ="", p_instanceVars = "", p_instanceProperties = "")
{
	static

	_EnterCriticalSection()

	if (p_TriggerID = "")
	{
		;If trigger is not assigned, try to find the default manual trigger
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
		; we have a trigger (either passed with p_TriggerID or the default manual trigger)
		; start a new instance
		environment := Object()
		environment.flowID := p_FlowID
		environment.elementID := p_TriggerID
		newInstance(environment, p_instanceVars, p_instanceProperties)
	}
	
	_LeaveCriticalSection()
	
	if not p_TriggerID
	{
		; we have no trigger ID. Probably because user tried manually to execute a trigger which has no manual trigger
		logger("F0", lang("There is no default manual trigger available"), _getFlowProperty(oneThreadFlowID, "Name"), true)
	}	
	return
}

; stop the execution of a flow
; this will stop all running instances of a flow
stopFlow(p_FlowID)
{
	_EnterCriticalSection()
	
	; loop through all instances
	InstanceIDs := _getAllInstanceIds()
	for OneInstanceIndex, OneInstanceID in InstanceIDs
	{
		; check the flow ID of the instance
		if (_getInstanceProperty(OneInstanceID, "FlowID") == p_FlowID)
		{
			; stop the instance
			stopInstance(OneInstanceID)
		}
	}
	_LeaveCriticalSection()
}

; stop a single instance of a flow
stopInstance(p_instanceID)
{
	; set the state of the instance to "stopping"
	; this will cause the execution task to stop the instance
	_setInstanceProperty(p_instanceID, "state", "stopping")
}

; toggle the execution of the flow
; stop execution if flow is running. Start a new instance if flow is not running.
executeToggleFlow(p_FlowID)
{
	_EnterCriticalSection()

	if (_getFlowProperty(p_FlowID, "executing"))
	{
		; flow is running. Stop it
		stopFlow(p_FlowID)
	}
	else
	{
		; flow is not running. start a new instance
		ExecuteFlow(p_FlowID)
	}
	
	_LeaveCriticalSection()
}

; Creates a new execution thread inside the given instance
; if p_ToCloneFromThread is given, the thread will be cloned
newThread(p_InstanceID, p_ToCloneFromThreadID ="")
{
	_EnterCriticalSection()

	if (p_ToCloneFromThreadID)
	{
		;Do a clone of the thread
		newThread := _getThread(p_InstanceID, p_ToCloneFromThreadID)

		;Assign another thread id
		newThread.id := "thread" ++global_ThreadIdCounter
		newThread.ThreadID := newThread.id
	}
	else
	{
		;Create a new thread (which will start at the trigger)
		newThread := Object()
		newThread.id := "thread" ++global_ThreadIdCounter
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
	}
	
	; add the thread to the instance
	_setThread(p_InstanceID, newThread.id, newThread)

	_LeaveCriticalSection()
	return newThread.ID
}

; remove a thread from an intance.
; this is called when a thread finishes
removeThread(p_instanceID, p_threadID)
{
	_EnterCriticalSection()

	; delete the thread
	_deleteThread(p_instanceID, p_threadID)

	; check whether the instance has any thread
	if (_getAllThreadIds(p_instanceID).count() = 0)
	{
		; the instance has no threads. Remove the instance
		removeInstance(p_instanceID)
	}
	_LeaveCriticalSection()
}

; remove an instance
; this is called when the intance finishes
removeInstance(p_instanceID)
{
	_EnterCriticalSection()

	; if there is a callback, call it and tell the waiting function that this instance has finished
	tempCallBackfunc := _getInstanceProperty(p_InstanceID, "callback", false)
	if (tempCallBackfunc)
	{
		%tempCallBackfunc%("finished", _getInstanceProperty(p_InstanceID, "InstanceVars"))
	}
	
	; delete the instance
	_deleteInstance(p_instanceID)
	updateFlowExcutingStates()

	_LeaveCriticalSection()
}

; updates the "executing" property of all flows.
updateFlowExcutingStates()
{
	_EnterCriticalSection()

	; loop through all isntances and make a list of all flows which are executing
	executingFlows := Object()
	Instances := _getAllInstanceIds()
	for OneInstanceIndex, OneInstanceID in Instances
	{
		executingFlows[_getInstanceProperty(OneInstanceID, "flowID")] := True
	}

	; loop through all flows and set the "executing" property
	Flows := _getAllFlowIds()
	for OneFlowIndex, OneFlowID in Flows
	{
		; check whether the flos ID is in list executingFlows and set the "executing" property
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