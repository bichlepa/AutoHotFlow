global global_AllExecutionIDs := Object()
global global_AllActiveTriggerIDs := Object()

; execution task processing which never returns
executionTask()
{
	global currentState

	; this variable will contain the elements which are ready to be executed
	ExecutionNextTasks := Object()
	
	Loop
	{
		_EnterCriticalSection()
		executingFlows := Object()
		somethingexecuted := false

		instances := _getAllInstanceIds()
		; loop through all instances
		for OneInstanceIndex, OneInstanceID in instances
		{
			OneInstance := _getInstance(OneInstanceID)
			
			; get the execution policy setting
			ExecutionPolicy := _getFlowProperty(OneInstance.FlowID, "ExecutionPolicy")
			if (ExecutionPolicy = "default")
			{
				ExecutionPolicy := _getSettings("FlowExecutionPolicy")
			}
		
			;If only one instance is allowed in this flow, and other should wait
			if (ExecutionPolicy = "wait")
			{
				; the execution policy is set to "wait".
				; We can only execute the first instance in this flow and others must wait until the instance has finished.
				if (executingFlows.haskey(OneInstance.flowID))
				{
					;Do not execute this instance yet
					continue
				}
				executingFlows[OneInstance.flowID] := True
			}
			
			; loop through all threads
			threads := _getAllThreadIds(OneInstanceID)
			for OneThreadIndex, OneThreadID in threads
			{
				;look in which state the thread is and perform an action
				OneThreadState := _getThreadProperty(OneInstanceID, OneThreadID, "state")
				
				if (OneThreadState = "starting") ;The element execution is ready to be started
				{
					; The element is waiting to be executed. Create task in variable ExecutionNextTasks
					
					; get some information
					oneThreadFlowID := _getThreadProperty(OneInstanceID, OneThreadID, "flowID")
					oneThreadElementID := _getThreadProperty(OneInstanceID, OneThreadID, "ElementID")
					oneThreadResult := _getThreadProperty(OneInstanceID, OneThreadID, "result")
					
					; We take the data from the dataset of the current state. Otherwise it can cause trouble if user is editing the flow while it is executing.
					currentFinishedElement := _getElementFromState(OneThreadFlowID, OneThreadElementID)
					oneElementClass := currentFinishedElement.class
					
					; change some thread properties
					_setThreadProperty(OneInstanceID, OneThreadID, "state", "running")
					_setThreadProperty(OneInstanceID, OneThreadID, "ElementPars", currentFinishedElement.pars)

					; change some element properties for proper rendering
					_setElementProperty(OneThreadFlowID, OneThreadElementID, "state", "running")
					_getAndIncrementElementProperty(OneThreadFlowID, OneThreadElementID, "countRuns")
					_setFlowProperty(OneThreadFlowID, "draw.mustDraw", true)
					
					; generate a unique ID and prepare object for temporary values during execution
					UniqueID := OneInstanceID "_" OneThreadID "_" OneThreadElementID "_" A_TickCount
					_setThreadProperty(OneInstanceID, OneThreadID, "UniqueID", UniqueID)
					_setThreadProperty(OneInstanceID, OneThreadID, "ElementExecutionValues", Object())

					; create a variable which contains all unique IDs and their environments and also some other temporary variables
					global_AllExecutionIDs[UniqueID] := Object()
					global_AllExecutionIDs[UniqueID].Environment := {instanceID: OneInstanceID, threadID: OneThreadID, flowID: OneThreadFlowID, elementID: OneThreadElementID}
					
					if Isfunc("Element_run_" oneElementClass)
					{
						;Add the element to the queue. It will be executed later
						ExecutionNextTasks.push({func: "Element_run_" oneElementClass, Environment: {instanceID: OneInstanceID, threadID: OneThreadID, flowID: OneThreadFlowID, elementID: OneThreadElementID}})
					}
					else
						MsgBox Unexpected error! Function for running element does not exist: Element_run_%oneElementClass%
					
					somethingexecuted := true
				}
				else if (OneThreadState = "finished") ;The element execution has finished
				{
					;If the element execution has finished, check the result and find next elements to be executed and prepare the next execution
					
					; get some information
					oneThreadFlowID := _getThreadProperty(OneInstanceID, OneThreadID, "flowID")
					oneThreadElementID := _getThreadProperty(OneInstanceID, OneThreadID, "ElementID")
					oneThreadResult := _getThreadProperty(OneInstanceID, OneThreadID, "result")
					
					; We will try to find connections which start from the current element and which have the same type as the current result 
					AnyConnectionFound := False
					; We take the data from the dataset of the current state. Otherwise it can cause trouble if user is editing the flow while it is executing.
					currentFinishedElement := _getElementFromState(oneThreadFlowID, oneThreadElementID)
					; loop through all connections which start from the element
					for oneConnectionIndex, oneConnectionID in currentFinishedElement.FromConnections
					{
						; get some information about the connection. Again we take the data from the dataset of the current state
						currentConnection := _getConnectionFromState(oneThreadFlowID, oneConnectionID)

						; check whether the connection matches the current result
						; if current element is a loop, the result contains the allowed part of the loop
						if ((currentConnection.ConnectionType = oneThreadResult) or (currentFinishedElement.type = "Loop" and currentConnection.fromPart = oneThreadResult))
						{
							; If leaving a loop, we have to restore the loop values from stack
							; that means, delete current loop variables and if there is an outside loop, make the loop variables of outside loop visible
							if (currentFinishedElement.type = "loop" and (oneThreadResult = "tail" or oneThreadResult = "exception"))
							{
								LoopVariable_RestoreFromStack(OneInstanceID, OneThreadID)
							}
							
							; We will need to clone the thread if we have more than one matching connections
							NextThreadID := OneThreadID
							if (AnyConnectionFound = True)
							{
								NextThreadID := newThread(OneInstanceID, OneThreadID)
							}

							; assign the next element which will be executed
							_setThreadProperty(OneInstanceID, NextThreadID, "ElementID", currentConnection.to)
							_setThreadProperty(OneInstanceID, NextThreadID, "ElementEntryPoint", currentConnection.toPart)
							currentStartingElement := _getElementFromState(oneThreadFlowID, currentConnection.to)
							
							; If entering a loop, we need to add current loop variables to stack
							; that means, make current loop variables invisible, so that the loop variables of the next inner loop won't interfere
							if (currentStartingElement.type = "loop" and _getThreadProperty(OneInstanceID, NextThreadID, "ElementEntryPoint") = "head")
							{
								LoopVariable_AddToStack(OneInstanceID, OneThreadID)
							}
							
							; update the state of the thread
							_setThreadProperty(OneInstanceID, NextThreadID, "state", "starting")
							
							AnyConnectionFound := True
						}
					}
					if not AnyConnectionFound
					{
						; we did not find any matching connections.
						if (OneThreadResult = "exception")
						{
							; we have an exception which was not handled by a matching connection. Show error message to user
							; todo: make a non-blocking gui
							oneThreadMessage := _getThreadProperty(OneInstanceID, OneThreadID, "message")
							MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') ended with an exception.", lang(_getThreadProperty(oneThreadFlowID, OneThreadElementID, "type")), _getThreadProperty(oneThreadFlowID, OneThreadElementID, "name"), OneThreadElementID) "`n`n" OneThreadMessage
						}

						; remove the current thread
						removeThread(OneInstanceID, OneThreadID)
					}

					somethingexecuted := true
				}
				else if (OneThreadState = "running") ;The element execution is currently running
				{
					;The element execution takes longer. We will wait
				}
				else if (OneThreadState = "stopping")
				{
					;Do nothing
				}
				Else
				{
					throw exception("State of thread '" OneThreadID "' is unknown!")
				}
			}
		}
		
		_LeaveCriticalSection()

		; Actually execute the elements which are queued for execution
		; the above code is more important therefore we only execute an action if nothing has been changed
		;   and we only execute one element at time
		if (not somethingexecuted)
		{
			oneExecutionTask := ExecutionNextTasks.pop()
			func := oneExecutionTask.func
			%func%(oneExecutionTask.Environment, _getThreadProperty(oneExecutionTask.environment.InstanceID, oneExecutionTask.environment.ThreadID, "elementpars"))
			somethingexecuted := true
		}		

		if (not somethingexecuted)
		{
			; we had nothing to do. Do a sleep to save CPU time
			sleep, 10
		}
	}
	
}

; called when the execution of an element finishes
finishExecutionOfElement(p_InstanceID, p_ThreadID, p_Result, p_Message = "")
{
	_EnterCriticalSection()

	; write the information from function parameteres as thread properties
	_setThreadProperty(p_InstanceID, p_ThreadID, "State", "finished")
	_setThreadProperty(p_InstanceID, p_ThreadID, "result", p_Result)
	_setThreadProperty(p_InstanceID, p_ThreadID, "message", p_Message)

	; get some information about the current element and flow
	ElementID := _getThreadProperty(p_InstanceID, p_ThreadID, "ElementID")
	FlowID := _getThreadProperty(p_InstanceID, p_ThreadID, "FlowID")
	FlowName := _getFlowProperty(FlowID, "Name")
	
	; log this event
	if (p_Message)
		logger("f1", "Execution of element " ElementID " finished with result " p_Result " and message: " p_Message, FlowName)
	else
		logger("f2", "Execution of element " ElementID " finished with result " p_Result, FlowName)
	
	; make sure, the element is highlighted properly
	countRuns := _getAndIncrementElementProperty(FlowID, ElementID, "countRuns", -1)
	if (countRuns = 0)
		_setElementProperty(FlowID, ElementID, "state", "finished")
	_setElementProperty(FlowID, ElementID, "lastrun", a_tickcount)
	_setFlowProperty(FlowID, "draw.mustDraw", true)
	
	; delete some temporary variables
	uniqueID := _getThreadProperty(p_InstanceID, p_ThreadID, "uniqueID")
	global_AllExecutionIDs.delete(uniqueID)
	_setThreadProperty(p_InstanceID, p_ThreadID, "uniqueID", "")
	_setThreadProperty(p_InstanceID, p_ThreadID, "ElementExecutionValues", "")
	
	; set a thread variable if we have an exception
	if (p_Result = "Exception")
	{
		ThreadVariable_Set({instanceID: p_InstanceID, threadID: p_ThreadID, flowID: FlowID, elementID: ElementID}, "a_ErrorMessage", p_Message)
	}

	_LeaveCriticalSection()
}