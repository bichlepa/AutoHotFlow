

executionTask()
{
	global _execution, _flows, _settings, currentState
	;TODO Vielleicht wird es zu Problemen kommen, wenn neue Instanzen hinzugefügt werden, während diese Schleife läuft
	
	Loop
	{
		somethingexecuted:=false
		for OneInstanceID, OneInstance in _execution.Instances
		{
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
					
					if Isfunc("Element_run_" oneElementClass )
						Element_run_%oneElementClass%(OneThread, OneThread.elementpars)
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
					;~ d(_flows[OneThread.flowID].states[currentState].allElements[OneThread.elementID], "element " OneThread.elementID) 
					for oneConnectionIndex, oneConnectionID in _flows[OneThread.flowID].states[_flows[OneThread.flowID].currentState].allElements[OneThread.elementID].FromConnections
					{
						;~ d(_flows[OneThread.flowID].allConnections[oneConnectionID], "connection found: " oneConnectionID)
						if (_flows[OneThread.flowID].states[_flows[OneThread.flowID].currentState].allConnections[oneConnectionID].ConnectionType = OneThread.result)
						{
							NextThread := OneThread
							if (AnyConnectionFound=True)
							{
								;On other than first connection first clone the thread
								NextThread := newThread(OneInstance, OneThread)
								;~ d(NextThread, "cloned thread")
							}
							;assign the next element to this thread
							NextThread.ElementID := _flows[OneThread.flowID].states[_flows[OneThread.flowID].currentState].allConnections[oneConnectionID].to
							NextThread.state:="starting"
							
							AnyConnectionFound:=True
						}
					}
					if not AnyConnectionFound
					{
						if (OneThread.result = "exception")
						{
							MsgBox % "beendet mit Fehler: `n`n" OneThread.message
						}
						;~ d(OneThread, "remove thread")
						removeThread(OneThread)
					}
					somethingexecuted:=true
				}
				else
				{
					MsgBox Unexpected error! State of thread %OneThreadID% unknown!
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
	_flows[Environment.FlowID].allElements[Environment.ElementID].countRuns--
	if (_flows[Environment.FlowID].allElements[Environment.ElementID].countRuns==0)
		_flows[Environment.FlowID].allElements[Environment.ElementID].state:="finished"
	_flows[Environment.FlowID].allElements[Environment.ElementID].lastrun:=a_tickcount
	_flows[Environment.FlowID].draw.mustDraw:=true
	if (result = "Exception")
	{
		ThreadVariable_Set(Environment,"a_ErrorMessage",Message,p_ContentType="Normal")
	}
}