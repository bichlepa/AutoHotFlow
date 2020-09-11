global global_AllExecutionIDs:=Object()
global global_AllActiveTriggerIDs:=Object()

executionTask()
{
	global currentState

	executingFlows:=Object()
	
	Loop
	{
		_EnterCriticalSection()
		somethingexecuted:=false
		ExecutionNextTasks:=Object()
		;Find out which elements need to be executed. Also manage finished elements and prepare them if needed
		instances:=_getAllInstanceIds()
		for OneInstanceIndex, OneInstanceID in instances
		{
			OneInstance := _getInstance(OneInstanceID)
			; d(OneInstance)
			ExecutionPolicy := _getFlowProperty(OneInstance.FlowID, "ExecutionPolicy")
			if (ExecutionPolicy = "default")
				ExecutionPolicy:=_getSettings("FlowExecutionPolicy")
			
			if (OneInstance.state="init")
			{
				;Do not execute as long it is in initialisation state
			}
			else
			{
				;If only one instance is allowed in this flow, and other should wait
				if (ExecutionPolicy="wait")
				{
					if (executingFlows.haskey(OneInstance.flowID))
					{
						;Do not execute this instance yet
						continue
					}
					executingFlows[OneInstance.flowID]:=True
				}
				
				;look in which state the thread is and perform an action
				threads := _getAllThreadIds(OneInstanceID)
				for OneThreadIndex, OneThreadID in threads
				{
					OneThread := _getThread(OneInstanceID, OneThreadID)
					; d(OneThread, "Schleifenstart: for OneInstance.threads")
					if (OneThread.state="starting") ;The element execution is ready to be started
					{
						;Execute the element.
						
						; We take the data from the dataset of the current state. Otherwise it can cause trouble if user is editing the flow while it is executing.
						currentFinishedElement := _getElementFromState(OneThread.flowID, OneThread.ElementID)

						oneElementClass := currentFinishedElement.class
						
						_setThreadProperty(OneInstanceID, OneThreadID, "state", "running")
						_setThreadProperty(OneInstanceID, OneThreadID, "ElementPars", currentFinishedElement.pars)

						_setElementProperty(OneThread.flowID, OneThread.elementID, "state", "running")
						_getAndIncrementElementProperty(OneThread.flowID, OneThread.elementID, "countRuns")
						
						_setFlowProperty(OneThread.flowID, "draw.mustDraw", true)
						
						UniqueID := OneThread.instanceID "_" OneThread.threadID "_" OneThread.elementID "_" A_TickCount
						_setThreadProperty(OneInstanceID, OneThreadID, "UniqueID", UniqueID)
						_setThreadProperty(OneInstanceID, OneThreadID, "ElementExecutionValues", Object())

						global_AllExecutionIDs[OneThread.UniqueID]:=Object()
						global_AllExecutionIDs[OneThread.UniqueID].Environment:={instanceID: OneInstanceID, threadID: OneThreadID, flowID: OneThread.flowID, elementID: OneThread.elementID}
						;~ d(global_AllExecutionIDs, OneThread.UniqueID)
						if Isfunc("Element_run_" oneElementClass )
						{
							;Add the element to the queue. It will be executed later
							ExecutionNextTasks.push({func: "Element_run_" oneElementClass, Environment: {instanceID: OneInstanceID, threadID: OneThreadID, flowID: OneThread.flowID, elementID: OneThread.elementID}})
						}
						else
							MsgBox Unexpected error! Function for running element does not exist: Element_run_%oneElementClass%
						
						somethingexecuted:=true
					}
					else if (OneThread.state="running") ;The element execution is currently running
					{
						;The element execution takes longer. We will wait
						
					}
					else if (OneThread.state="finished") ;The element execution has finished
					{
						;If the element execution has finished, check the result and find next elements to be executed and prepare the next execution
						
						;Find connections
						AnyConnectionFound:=False
						
						; We take the data from the dataset of the current state. Otherwise it can cause trouble if user is editing the flow while it is executing.
						currentFinishedElement := _getElementFromState(OneThread.flowID, OneThread.ElementID)
						for oneConnectionIndex, oneConnectionID in currentFinishedElement.FromConnections
						{
							currentConnection := _getConnectionFromState(OneThread.flowID, oneConnectionID)
							if ((currentConnection.ConnectionType = OneThread.result) or (currentFinishedElement.type = "Loop") and currentConnection.fromPart = OneThread.result)
							{
								;If leaving a loop
								if (currentFinishedElement.type = "loop" and (OneThread.result = "tail" or OneThread.result = "exception"))
								{
									LoopVariable_RestoreFromStack(OneThread)
								}
								
								
								NextThreadID := OneThreadID
								if (AnyConnectionFound=True)
								{
									;On other than first connection first clone the thread
									NextThreadID := newThread(OneInstanceID, OneThreadID)
								}
								;assign the next element to this thread
								_setThreadProperty(OneInstanceID, NextThreadID, "ElementID", currentConnection.to)
								_setThreadProperty(OneInstanceID, NextThreadID, "ElementEntryPoint", currentConnection.toPart)
								currentStartingElement := _getElementFromState(OneThread.flowID, currentConnection.to)
								
								;If entering a loop
								if (currentStartingElement.type = "loop" and _getThreadProperty(OneInstanceID, NextThreadID, "ElementEntryPoint") = "head")
								{
									LoopVariable_AddToStack(NextThreadID)
								}
								
								_setThreadProperty(OneInstanceID, NextThreadID, "state", "starting")
								
								AnyConnectionFound:=True
							}
						}
						if not AnyConnectionFound
						{
							if (OneThread.result = "exception")
							{
								MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') ended with an exception.", lang(_getThreadProperty(OneThread.flowID, OneThread.elementID, "type")), _getThreadProperty(OneThread.flowID, OneThread.elementID, "name"), OneThread.elementID) "`n`n" OneThread.message
							}
							removeThread(OneThread.InstanceID, OneThread.ID)
						}
						somethingexecuted:=true
					}
					else if (OneThread.state="stopping")
					{
						;Do nothing
					}
					else
					{
						MsgBox Unexpected error! State of thread %OneThreadID% unknown!
					}
					
				}
			}
		}
		
		_LeaveCriticalSection()

		;Actually execute the elements which are queued for execution
		for oneExecutionTaskIndex, oneExecutionTask in ExecutionNextTasks
		{
			func:=oneExecutionTask.func
			%func%(oneExecutionTask.Environment, _getThreadProperty(oneExecutionTask.environment.InstanceID, oneExecutionTask.environment.ThreadID, "elementpars"))
		}				

		if (somethingexecuted=False)
			break
	}
	
}

finishExecutionOfElement(p_InstanceID, p_ThreadID, p_Result, p_Message = "")
{
	_EnterCriticalSection()

	_setThreadProperty(p_InstanceID, p_ThreadID, "State", "finished")
	_setThreadProperty(p_InstanceID, p_ThreadID, "result", p_Result)
	_setThreadProperty(p_InstanceID, p_ThreadID, "message", p_Message)
	ElementID := _getThreadProperty(p_InstanceID, p_ThreadID, "ElementID")
	FlowID := _getThreadProperty(p_InstanceID, p_ThreadID, "FlowID")
	FlowName := _getFlowProperty(FlowID, "Name")
	
	if (p_Message)
		logger("f2", "Execution of element " ElementID " finished with result " p_Result " and message: " p_Message, FlowName)
	else
		logger("f2", "Execution of element " ElementID " finished with result " p_Result, FlowName)
	
	countRuns := _getAndIncrementElementProperty(FlowID, ElementID, "countRuns", -1)
	if (countRuns = 0)
		_setElementProperty(FlowID, ElementID, "state", "finished")
	_setElementProperty(FlowID, ElementID, "lastrun", a_tickcount)
	_setFlowProperty(FlowID, "draw.mustDraw", true)
	
	;~ d(global_AllExecutionIDs, Environment.uniqueID)
	uniqueID := _getThreadProperty(p_InstanceID, p_ThreadID, "uniqueID")
	global_AllExecutionIDs.delete(uniqueID)
	_setThreadProperty(p_InstanceID, p_ThreadID, "uniqueID", "")
	_setThreadProperty(p_InstanceID, p_ThreadID, "ElementExecutionValues", "")
	
	if (result = "Exception")
	{
		ThreadVariable_Set({instanceID: p_InstanceID, threadID: p_ThreadID, flowID: FlowID, elementID: ElementID}, "a_ErrorMessage", p_Message)
	}
	_LeaveCriticalSection()
	;~ d(Environment, message)
}