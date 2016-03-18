ReadyToStartInstances:=new ObjectWithCounter()

r_nowrunning:=false
ReadyToStartInstances:=[]
Execution.stopnow:=false
Execution.running:=false
CriticalSectionAllInstances:=CriticalSection()

;Start new execution threads
r_StartExecutionThreads()
{
	global
	
	Loop % share.flowSettings.MaximumCountOfExeThreads
	{
		AhkThreadExecution%a_index% := AhkThread("CriticalSectionAllInstances := CriticalSection("CriticalSectionAllInstances ")`nshare:=CriticalObject(" (&share) ") `n allTriggers:=CriticalObject(" (&allTriggers) ") `n allConnections:=CriticalObject(" (&allConnections) ") `n allElements:=CriticalObject(" (&allElements) ") `n allInstances:=CriticalObject(" (&allInstances) ") `n allThreads:=CriticalObject(" (&allThreads) ") `n mainguihwnd:=""" maingui.hwnd """`n" ExecutionThreadCode)
	}
	;~ MsgBox aweg
}


;Called when a new instance should be triggered
;p_parameter contains some of following informations.
; - Variables
r_Trigger(p_Trigger,p_parameter="")
{
	;~ MsgBox r_Trigger
	global c_PriorityForInstanceInitialization, ReadyToStartInstances
	
	
	tempinstance:=[]
	tempinstance.parameters:=p_parameter
	tempinstance.trigger:=p_Trigger
	ReadyToStartInstances.push(tempinstance)
	;~ d(tempinstance,0709)
	;~ d(instance,07409)
	;~ d(ReadyToStartInstances)
	SetTimer,r_StartNewInstance,-10,%c_PriorityForInstanceInitialization%
}

r_StartNewInstance()
{
	global allInstances, allThreads, c_PriorityForIteration , ReadyToStartInstances , maintrigger, share, CriticalSectionAllInstances
	;Find all pending instances and make them ready to launch
	
	;~ MsgBox r_StartNewInstance
	Loop
	{
		;~ tempInstance:=""
		tempInstanceID:=""
		for, forIndex, forInstance in ReadyToStartInstances
		{
			tempInstance:=forInstance
			tempInstanceIndex:=forIndex
			break
		}
		
		if (ReadyToStartInstances.count()>0)
		{
			
			if (Execution.running=true) ;If the flow is already running.
			{
				;Consider the execution policy setting
				if (share.flowSettings.ExecutionPolicy="stop") ;Stop current instance and start a new one
				{
					logger("f1","An instance already exists. Old execution stopped in order to launch the new one.")
					instance_StopAll()
					;~ SetTimer,r_WaitUntilStoppedAndThenStart,50 ;TODO
					return
				}
				else if (share.flowSettings.ExecutionPolicy="skip") ;Skip the execution
				{
					logger("f1","An instance already exists. Execution skipped.")
					return
				}
				else if (share.flowSettings.ExecutionPolicy="wait" or share.flowSettings.ExecutionPolicy="parallel") ;Wait until the current instance has finished
				{
					if (allInstances.count()>share.flowSettings.MaximumCountOfParallelInstances)
					{
						;TODO: emergency stop if too many parallel executions
						Logger("f1","Already " share.flowSettings.MaximumCountOfParallelInstances "Instances are running. Skipping execution")
						return
					}
					
					if (share.flowSettings.ExecutionPolicy="wait")
					{
						logger("f2","An instance already exists. Execution will wait.")
					}
					else
						logger("f2","An instance already exists. This instance is going to run parallel.")
					
				}
				
			}
			
			
			tempInstanceID:=instance_New()
			;~ EnterCriticalSection(CriticalSectionAllInstances)
			if isobject(tempInstance[tempInstanceID].parameters)
			{
				
				;~ MsgBox % strobj(Execution_Parameters)
				allInstances[tempInstanceID].CallingFlow:=tempInstance[tempInstanceID].parameters["SendingFlow"]
				allInstances[tempInstanceID].ElementIDInCallingFLow:=tempInstance[tempInstanceID].parameters["CallerElementID"]
				allInstances[tempInstanceID].InstanceIDOfCallingFlow:=tempInstance[tempInstanceID].parameters["CallerInstanceID"]
				allInstances[tempInstanceID].ThreadIDOfCallingFlow:=tempInstance[tempInstanceID].parameters["CallerThreadID"]
				allInstances[tempInstanceID].WhetherToReturVariables:=tempInstance[tempInstanceID].parameters["WhetherToReturVariables"]
				
				;~ MsgBox % Execution_Parameters["localVariables"] "`n`n" strobj(Execution_Parameters)
				
				;Import variables if the trigger provides some variables or if an other flow has called this flow. ;TODO
				;~ if isobject(tempInstanceID.parameters["localVariables"])
					;~ v_ImportLocalVariablesFromObject(r_RunningCounter,tempInstanceID.parameters["localVariables"])
				;~ else
					;~ v_ImportLocalVariablesFromString(r_RunningCounter,tempInstanceID.parameters["localVariables"])
				
				;~ if isobject(tempInstanceID.parameters["threadVariables"])
				;~ {
					;~ v_ImportThreadVariablesFromObject(r_RunningCounter,r_RunningThreadCounter,tempInstanceID.parameters["ThreadVariables"])
				;~ }
				;~ else
					;~ v_ImportThreadVariablesFromString(r_RunningCounter,r_RunningThreadCounter,tempInstanceID.parameters["ThreadVariables"])
				
				logger("f2",allInstances[tempInstanceID].id ": the flow was called by " allInstances[tempInstanceID].CallingFlow)
			}
			
			allThreads[allInstances[tempInstanceID].firstthread].element:=maintrigger
			allThreads[allInstances[tempInstanceID].firstthread].lastResult:="normal"
			allThreads[allInstances[tempInstanceID].firstthread].state:="finished"
			;~ d(tempInstanceID)
			;~ d(allInstances[tempInstanceID])
			;set some variables for correct  visual appearance of the trigger
			;TODO
			
			
			;Move the instance from ready to running
			ReadyToStartInstances.delete(tempInstanceIndex)
			;~ allInstances[tempInstanceid]:=tempInstance
			
			;~ LeaveCriticalSection(CriticalSectionAllInstances)
			somethingInitialized:=true
		}
		else
			break
	}
	
	if (somethingInitialized) ;if not already running, execute the r_run() function. of not the currently running r_run function will find that new thread
	{
		Execution.running:=true
		;~ Execution.stopnow:=false
		
		r_OnChange()
		
		;~ r_TellThatFlowIsStarted() ;Tell manager that flow has started. Also replace some text in the GUI buttons.
		UI_draw()
	}
	
	logger("f1","Starting new instance")
	
	SetTimer,r_Iteration,-10,%c_PriorityForIteration%
}

r_OnChange()
{
	global
	loop % share.flowSettings.MaximumCountOfExeThreads
	{
		AhkThreadExecution%a_index%.ahkFunction("extern_changeDetected")
	}
}


r_Iteration()
{
	;~ MsgBox r_Iteration
	global execution, FlowLastActivity, runNeedToRedraw, allInstances
	global currentStateID, states
	global allelements, allConnections, allTriggers
	FlowLastActivity:=a_now
	runNeedToRedraw:=false
	
	;When starting an iteration, a copy will be made of the current state. This will prevent data inconsistency if user changes something during execution
	if (execution.stateID!=currentstateID)
	{
		logger("f3","Copying current state " currentStateID " for execution")
		Execution.state:=ObjFullyClone(states[currentStateID])
		execution.stateID:=currentStateID
		
		;Write to all element the information, which connections start from them. this will make things easier later
		for forID, forElement in Execution.state.allConnections
		{
			;~ d(Execution.state.allConnections,145)
			;~ d(Execution.state.allElements,2431)
			
			if (not IsObject(Execution.state.allElements[forElement.from].To))
			{
				;~ d(forElement,16234)
				Execution.state.allElements[forElement.from].To:=[]
			}
			Execution.state.allElements[forElement.from].To.push(forElement.id)
			;~ d(Execution.state.allElements[forElement.from],14)
		}
	}
	
	
	
	;~ PendingExecutions:=new ObjectWithCounter()
	CopyOfInstances:=allInstances.clone()
	;~ d(Execution,1)
	for forInstanceID, forInstance in CopyOfInstances ;Go through all instances
	{
		logger("f3","Proceeding instance " forInstanceID)
		CopyOfThreads:=forInstance.threads.clone()
		
		;~ d(forInstance,3451)
		for forThreadID, forThread in CopyOfThreads
		{
			logger("f3","Proceeding thread " forThreadID)
			result:=""
			finished:=false
			if (not IsObject(forThread.execution)) ;Start from the Trigger
			{
				;~ d("gaagr",1)
				result:="normal"
				finished:=true
				forThread.element:=Execution.state.allElements.trigger
				allelements[forThread.element.id].isRunning:=false
				allelements[forThread.element.id].lastRun:=a_tickcount
					ui_draw()
				logger("f3","element " forThread.element.id " ended with result '" result "'")
			}
			else ;Check whether the current execution has finished and get the result
			{
				;~ d("hhdr",1)
				if (forThread.execution.finished)
				{
					result:=forThread.execution.result
					finished:=true
					allelements[forThread.element.id].isRunning:=false
					allelements[forThread.element.id].lastRun:=a_tickcount
					ui_draw()
					logger("f3","element " forThread.element.id " ended with result '" result "'")
				}
				else
				{
					logger("f3","element " forThread.element.id " is still running")
				}
			}
			
			
			if (result="Exception")
			{
				;~ d(forThread.execution,"8446516")
			}
			
			if (finished=true)
			{
				;~ d("awegerawg",1serh)
				ConnectionFound:=0
				;~ d(forThread.element,"hioawefhio")
				for forConnectionIndex, forConnectionID in forThread.element.to
				{
					tempConnection:=Execution.state.allConnections[forConnectionID]
					;~ d(tempConnection,"1h")
					;~ d(tempConnection.connectiontype "-" result,"541h")
					if (tempConnection.connectiontype=result)
					{
						;~ d("gserhtr",1)
						ConnectionFound++
						
						if (ConnectionFound=1)
						{
							tempThread:=forthread
							logger("f3","Found connection to '" tempConnection.to "'")
						}
						else
						{
							;~ d(forthread,56)
							tempThread:=forThread.cloneThread()
							;~ d(tempThread,5678)
							logger("f3","Found connection to " tempConnection.to "'. New thread created: '" tempThread.id "'")
						}
						
						tempThread.element:=Execution.state.allElements[tempConnection.to]
						
						tempElementType:=tempThread.element.type
						tempElementSubType:=tempThread.element.subtype
						
						;update variables for drawing
						allelements[tempThread.element.id].isRunning:=true
						allConnections[tempConnection.id].lastRun:=a_tickcount
						ui_draw()
						
						;TODO: prepare entering and leaving a loop
						logger("f3","Executing " tempElementType " '" tempElementSubType "'")
						tempThread.execution:=new %tempElementType%%tempElementSubType%(tempThread,tempThread.element)
						tempThread.execution.run()
						;~ MsgBox agrar
					}
					
					
				}
				
				if (ConnectionFound=0) ;End thread
				{
					;~ d("ghahtrrh",1)
					forThread.delete()
					logger("f3","No suitable connection found. Thread " forThreadID " ends")
				}
				
				
				
				
			}
			
			
		}
		
		if (forInstance.threads.count()=0)
		{
			;~ d("herhwe",1)
			forInstance.delete()
			logger("f3","Closing " forInstanceID " because all its threads eneded")
		}
		
		
	}
	
	if (allInstances.count()=0)
	{
		logger("f3","All instances finished")
		Execution.running:=false
	}
	else
	{
		SetTimer,r_Iteration,-10,%c_PriorityForInstanceInitialization%
	}
	
}


r_StopAll()
{
	cl_instance.stopall()
	
}