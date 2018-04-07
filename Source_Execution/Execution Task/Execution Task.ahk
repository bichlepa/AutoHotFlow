global global_AllExecutionIDs:=Object()
global global_AllActiveTriggerIDs:=Object()

executionTask()
{
	global currentState
	;TODO Vielleicht wird es zu Problemen kommen, wenn neue Instanzen hinzugefügt werden, während diese Schleife läuft
	executingFlows:=Object()
	
	Loop
	{
		somethingexecuted:=false
		
		for OneInstanceID, OneInstance in _execution.Instances
		{
			if (_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy = "default")
				ExecutionPolicy:=_settings.FlowExecutionPolicy
			else
				ExecutionPolicy:=_flows[p_Environment.FlowID].flowSettings.ExecutionPolicy
			
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
						;Do not execute this instance
						continue
					}
					executingFlows[OneInstance.flowID]:=True
				}
				
				;look in which state the thread is and perform an action
				for OneThreadID, OneThread in OneInstance.threads
				{
					;~ d(OneThread, "Schleifenstart: for OneInstance.threads")
					if (OneThread.state="starting") ;The element execution is ready to be started
					{
						;Execute the element.
						oneElement:=_flows[OneThread.flowID].allElements[OneThread.elementID]
						oneElementClass:=oneElement.class
						OneThread.ElementPars:=objfullyclone(oneElement.pars)
						
						OneThread.state:="running"
						oneElement.state:="running"
						oneElement.countRuns++
						
						_flows[OneThread.flowID].draw.mustDraw:=true
						;~ d(oneElement, "ausführen: " oneElement.id)
						;~ d(OneThread, "ausführen: " oneElement.id)
						
						OneThread.UniqueID:= OneThread.instanceID "_" OneThread.threadID "_" OneThread.elementID "_" A_TickCount
						OneThread.ElementExecutionValues:=Object()
						global_AllExecutionIDs[OneThread.UniqueID]:=Object()
						global_AllExecutionIDs[OneThread.UniqueID].Environment:=OneThread
						;~ d(global_AllExecutionIDs, OneThread.UniqueID)
						if Isfunc("Element_run_" oneElementClass )
							Element_run_%oneElementClass%(OneThread, OneThread.elementpars) ;OneThread is the environment for element execution
						else
							MsgBox Unexpected error! Function for running element does not exist: Element_run_%oneElementClass%
						
						somethingexecuted:=true
					}
					else if (OneThread.state="running") ;The element execution is currently running
					{
						;If the element execution takes longer, this will check whether the element has finished
						
					}
					else if (OneThread.state="finished") ;The element execution has finished
					{
						;If the element execution has finished, check the result and find next elements to be executed and prepare the next execution
						
						;Find connections
						AnyConnectionFound:=False
						
						currentState := _flows[OneThread.flowID].states[_flows[OneThread.flowID].currentState]
						currentFinishedElement := currentState.allElements[OneThread.ElementID]
						
						;~ d(_flows[OneThread.flowID].states[currentState].allElements[OneThread.elementID], "element " OneThread.elementID) 
						for oneConnectionIndex, oneConnectionID in currentFinishedElement.FromConnections
						{
							currentConnection := currentState.allConnections[oneConnectionID]
							;~ d(_flows[OneThread.flowID].allConnections[oneConnectionID], "connection found: " oneConnectionID)
							if ((currentConnection.ConnectionType = OneThread.result) or (currentFinishedElement.type = "Loop") and currentConnection.fromPart = OneThread.result)
							{
								;If leaving a loop
								if (currentFinishedElement.type = "loop" and (OneThread.result = "tail" or OneThread.result = "exception"))
								{
									LoopVariable_RestoreFromStack(OneThread)
								}
								
								
								NextThread := OneThread
								if (AnyConnectionFound=True)
								{
									;On other than first connection first clone the thread
									NextThread := newThread(OneInstance, OneThread)
									;~ d(NextThread, "cloned thread")
								}
								;assign the next element to this thread
								NextThread.ElementID := currentConnection.to
								NextThread.ElementEntryPoint := currentConnection.toPart
								currentStartingElement := currentState.allElements[NextThread.ElementID]
								
								;If entering a loop
								if (currentStartingElement.type = "loop" and NextThread.ElementEntryPoint = "head")
								{
									LoopVariable_AddToStack(NextThread)
								}
								
								
								NextThread.state:="starting"
								
								AnyConnectionFound:=True
							}
						}
						if not AnyConnectionFound
						{
							if (OneThread.result = "exception")
							{
								MsgBox, 16, % lang("Exception occured") , % lang("%1% '%2%' (ID '%3%') ended with an exception.", lang(_flows[OneThread.flowID].allElements[OneThread.elementID].type), _flows[OneThread.flowID].allElements[OneThread.elementID].name, OneThread.elementID) "`n`n" OneThread.message
							}
							;~ d(OneThread, "remove thread")
							removeThread(OneThread)
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
		if (somethingexecuted=False)
			break
	}
	
}

finishExecutionOfElement(Environment, Result, Message = "")
{
	global
	Environment.State:="finished"
	Environment.result:=Result
	Environment.message:=Message
	
	if (Environment.message)
		logger("f2", "Execution of element " Environment.ElementID " finished with result " Environment.result " and message: " Environment.message, Environment.FlowName)
	else
		logger("f2", "Execution of element " Environment.ElementID " finished with result " Environment.result, Environment.FlowName)
	
	_flows[Environment.FlowID].allElements[Environment.ElementID].countRuns--
	if (_flows[Environment.FlowID].allElements[Environment.ElementID].countRuns = 0)
		_flows[Environment.FlowID].allElements[Environment.ElementID].state:="finished"
	_flows[Environment.FlowID].allElements[Environment.ElementID].lastrun:=a_tickcount
	_flows[Environment.FlowID].draw.mustDraw:=true
	
	;~ d(global_AllExecutionIDs, Environment.uniqueID)
	global_AllExecutionIDs.delete(Environment.uniqueID)
	Environment.UniqueID:=""
	Environment.ElementExecutionValues:=""
	
	if (result = "Exception")
	{
		ThreadVariable_Set(Environment,"a_ErrorMessage",Message)
	}
	;~ d(Environment, message)
}