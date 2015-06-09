
;initialise with empty objects

InstanceIDList:=Object()
r_RunningCounter=0
r_RunningThreadCounter=0
executionSpeed=1



;Starts a new instance
r_startRun()
{
	global
	
	
	if (nowrunning=true) ;If the flow is already running.
	{
		;Consider the execution policy setting
		if SettingFlowExecutionPolicy=stop ;Stop current instance and start a new one
		{
			gosub r_escapeRun
			SetTimer,r_WaitUntilStoppedAndThenStart,50
			return
		}
		else if SettingFlowExecutionPolicy=wait ;Wait until the current instance has finished
		{
			temp= ;Do nothing. In the run loop will only the first instance be considered
		}
		else if SettingFlowExecutionPolicy=skip ;Skip the execution
		{
			
			return
		}
		else if SettingFlowExecutionPolicy=parallel ;Execute multiple instancec parallel
		{
			temp= ;Do nothing
		}
		
	}
	
	Critical on ;This code generates one instance. it should not be interrupted. (especially if a new instance should be created)
	r_RunningCounter++
	r_RunningThreadCounter++
	
	
	InstanceIDList.insert("Instance_" r_RunningCounter) ;Insert a new Instance
	Instance_%r_RunningCounter%_RunningCounter=1 ;Counter that is incremented every time a new element is going to run
	Instance_%r_RunningCounter%_RunningElements:=Object() ;Create an object for the instance containing the running elements
	Instance_%r_RunningCounter%_RunningElements.insert(r_RunningThreadCounter "_trigger_" Instance_%r_RunningCounter%_RunningCounter) ;A flow is always launched from trigger
	Instance_%r_RunningCounter%_LocalVariables:=Object() ;Create an object for the instance containing the running elements
	Instance_%r_RunningCounter%_Thread_%r_RunningThreadCounter%_Variables:=Object() ;Create an object for the instance containing the running elements
	
	;MsgBox %ThisExecution_CallingFlow%
	;MsgBox %ThisExecution_InstanceIDOfCallingFlow%
	;MsgBox %ThisExecution_WhetherToReturVariables%
	;MsgBox %ThisExecution_ElementIDInInstanceOfCallingFlow%
	;if an other flow has called this flow. Those variables will be needed to get the variables from the other flow, inform it when this flow has finished and send the variables back.
	Instance_%r_RunningCounter%_CallingFlow:=ThisExecution_CallingFlow
	Instance_%r_RunningCounter%_InstanceOfCallingFlow:=ThisExecution_InstanceIDOfCallingFlow
	Instance_%r_RunningCounter%_WhetherToReturVariables:=ThisExecution_WhetherToReturVariables
	Instance_%r_RunningCounter%_ElementIDInInstanceOfCallingFlow:=ThisExecution_ElementIDInInstanceOfCallingFlow
	
	;MsgBox %  r_RunningCounter "-"Instance_%r_RunningCounter%_CallingFlow
	 ;Import variables if the trigger provides some variables. E.g. if an other flow has called this flow.
	if ThisExecution_localVariables!=
	{
		
		loop, parse, ThisExecution_localVariables,◘
		{
			StringGetPos,temppos,A_LoopField,=
			if temppos!=
			{
				stringleft,tempVarName,A_LoopField,% temppos
				StringTrimLeft,tempVarContent,A_LoopField,% temppos+1
				v_setVariable(r_RunningCounter,1,tempVarName,tempVarContent)
				
			}
			
		}
		
		ThisExecution_localVariables=
		
	}
	v_setVariable(r_RunningCounter,ThreadID,"triggertime",a_now,"Date") ;Set the triggertime variable
	
	;set some variables for correct  visual appearance of the trigger
	if (triggerrunning<=0)
			triggerrunning=1
		else
			triggerrunning++
	Instance_%r_RunningCounter%_%r_RunningThreadCounter%_trigger_1_finishedRunning:=true 
	Instance_%r_RunningCounter%_%r_RunningThreadCounter%_trigger_1_result=normal
	
	
	if (nowRunning!=true) ;if not already running, execute the r_run() function. of not the currently running r_run function will find that new thread
	{
		nowRunning:=true
		stopRun:=false
		
		r_TellThatFlowIsStarted() ;Tell manager that flow has started. Also replace some text in the GUI buttons.
		Critical off
		UI_draw()
		r_run()
		
	}
	runNeedToRedraw:=true
	
	Critical off
	
	UI_draw()

	;Hotkey,esc,r_escapeRun,on
	
	
	

	
}

r_run()
{
	global

	
	
	nextrun: ;endless loop until no elements to execute left

	
	;lower the priority. This would make any interrupted ahk threads finish. (like redraw)
	thread, Priority, -100
	Thread, Interrupt, 0,0

	
	goingToRunIDs:=Object() ;contains the Element IDs with instance ID that are going to run now
	runNeedToRedraw:=false
	
	;The previous running elements are shown pink for a certain time
	for count, tempID in allElements
	{
		;The elements that have been running shortly before have a negative number that will be incremented until 0
		if (%tempID%running<0)
		{
			
			%tempID%running++
			if (%tempID%running=0)
				runNeedToRedraw:=true
		}
	}
	

	
	;MsgBox
	ElementsThatHaveFinished:=Object() ;Contains all elements that have finished right now
	InstancesThatHaveFinished:=Object() ;Contains all instances that have finishd right now
	;Go through all running instances. Find elements that are still running. Find elements that have finished and prepare connected elements to run. 
	for index1, tempInstanceID in InstanceIDList ;Go through all instances
	{
		if (SettingFlowExecutionPolicy="wait" && index1!=1) ;If execution policy allows only one running instance and others have to wait
			break
			
		
		
		
		tempCountOfRunningElementsInInstance=0 ;Empty the counter of running elements in the current instance. If the number will remain 0 the instance will be removed
		;MsgBox tempInstanceID %tempInstanceID%
		;Go through all running elements of the instance
		for index2, tempRunningElement in %tempInstanceID%_RunningElements
		{
			StringSplit, tempRunningElement,tempRunningElement,_ 
			; tempRunningElement1 = thread id
			; tempRunningElement2 = Element id
			; tempRunningElement3 = Element id in the instance
			
			;MsgBox %tempInstanceID%_%tempThreadID%_%tempRunningElement%_FinishedRunning = true ?
			if (%tempInstanceID%_%tempRunningElement%_FinishedRunning=true) ;If the element has finished
			{
				
				;mark the element that it has recently run by setting a negative number. It will be drawn pink. If several instances are running only decrement the number. Needed for correct visual appearance of the elements
				%tempRunningElement2%running--
				if (%tempRunningElement2%running=0)
					%tempRunningElement2%running=-10
				
				;Insert the element that has finished to the list
				ElementsThatHaveFinished.Insert(tempInstanceID "_"  tempRunningElement)
				
				
				runNeedToRedraw:=true
				
				;MsgBox, %tempRunningElement% finished running
				
				;Find elements that are connected to the finished element and prepare them to run
				tempConnectionCountToRun:=0
				for index1, element in allElements
				{
					
					if %element%Type=Connection
					{
						;MsgBox % "connection found " %element%from "  " tempRunningElement1 "  " %element%ConnectionType "  " %tempInstanceID%_%tempThreadID%_%tempRunningElement%_result
						tempTo:=%element%to
						tempFrom:=%element%from
						;~ MsgBox % %tempfrom%type "`n" %tempTo%type "`n" %element%ConnectionType "`n" %tempInstanceID%_%tempRunningElement%_result "`n" %element%frompart
						;If the connection starts on the currend finised element and the elements finished with the same result that is assigned to the connection
						if (%element%from=tempRunningElement2 && ( %element%ConnectionType=%tempInstanceID%_%tempRunningElement%_result || (%tempfrom%type="loop" && %element%ConnectionType = "normal" && ((%tempInstanceID%_%tempRunningElement%_result = "normalHead" && %element%frompart ="Head") || (%tempInstanceID%_%tempRunningElement%_result = "normalTail") && %element%frompart ="Tail")  )))
						{
							;~ MsgBox % "drin: " %tempTo%type "`n" %element%ConnectionType "`n" %tempInstanceID%_%tempRunningElement%_result "`n" %element%frompart
							if (tempConnectionCountToRun>0)
							{
								r_RunningThreadCounter++
								tempThreadIDToRun :=r_RunningThreadCounter
								%tempInstanceID%_Thread_%r_RunningThreadCounter%_Variables:=%tempInstanceID%_Thread_%tempRunningElement1%_Variables.Clone()
								;~ MsgBox tempInstanceID %tempInstanceID% `n r_RunningThreadCounter %r_RunningThreadCounter% `n tempRunningElement1 %tempRunningElement1%
								;~ MsgBox % StrObj(%tempInstanceID%_Thread_%tempRunningElement1%_Variables)
								;~ MsgBox % StrObj(%tempInstanceID%_Thread_%r_RunningThreadCounter%_Variables)
							}
							else
								tempThreadIDToRun:=tempRunningElement1
							
							%tempInstanceID%_RunningCounter++
							tempCountOfRunningElementsInInstance++
							
							if %tempFrom%type=Loop ;restore previous loop vars (if any) when leaving a loop
							{
								if (%element%frompart="Tail" or %element%ConnectionType = "exception") ;either normal leaving or exception
									PrepareLeavingALoop(tempInstanceID,tempThreadIDToRun,tempFrom)
								
							}
							
							tempRunSkipCurrentRun:=false
							;Insert the element that is on the end of the connection to the list
							if (%tempTo%type="Loop")
							{
								if %element%toPart = Head ;Save previous loop vars (if any) when entering a loop
								{
									PrepareEnteringALoop(tempInstanceID,tempThreadIDToRun,tempTo)
									
								}
								else if (%element%toPart = "Tail" or %element%toPart = "break") ;When entering a tail of the loop, check whether is was last on the head of the same loop
								{
									if (tempTo != %tempInstanceID%_Thread_%tempThreadIDToRun%_Variables["CurrentLoop"])
									{
										MsgBox, 16, % lang("Error"),% lang("The end of a loop was entered, but this loop was not the current one.")  "`n" lang("Current thread will be closed") 
										tempRunSkipCurrentRun:=true
									}
								}
								if (tempRunSkipCurrentRun != true)
								{
									goingToRunIDs.insert(tempInstanceID "_" tempThreadIDToRun "_" tempTo "_" %tempInstanceID%_RunningCounter "_" %element%toPart)
									tempConnectionCountToRun++
								}
							}
							else
							{
								goingToRunIDs.insert(tempInstanceID "_" tempThreadIDToRun "_" tempTo "_" %tempInstanceID%_RunningCounter)
								tempConnectionCountToRun++
							}
							;MsgBox % "going to run hinzugefügt "  tempInstanceID "_"  %element%to "_" %tempInstanceID%_RunningCounter
							
						}
						
						
						
						
					}
					
				}
				
			}
			else
			{
				
				
				;MsgBox, %tempRunningElement% still running
				tempCountOfRunningElementsInInstance++
				
			}
			
			
			
			
		
		}
		
		if (tempCountOfRunningElementsInInstance=0) ;Prepare to remove the instance, because no elements are running and thus the instance has finished
		{
			;MsgBox %tempInstanceID% was added to the list of instances that have finished
			InstancesThatHaveFinished.Insert(tempInstanceID)
			
		}
		
	}
	
	;Remove the elements that have finished running from the instance
	for index, tempElement in ElementsThatHaveFinished
	{
		StringSplit,tempElement,tempElement,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = thread id
		; tempElement4 = element id
		; tempElement5 = element id in the instance
		
		;MsgBox, element %tempElement% has finished and will be removed
		for index2, tempRunningElement in Instance_%tempElement2%_RunningElements
		{
			if (tempRunningElement=tempElement3 "_" tempElement4 "_" tempElement5)
			{
				
				
				runNeedToRedraw:=true
				Instance_%tempElement2%_RunningElements.Remove(index2)
				break
			}
		}
		
	}
	
	;Remove the instance that have finished from the list of instances
	for index, tempFinishedInstanceID in InstancesThatHaveFinished
	{
		;MsgBox, instance %tempFinishedInstanceID% has finished and will be removed
		for index1, tempInstanceID in InstanceIDList
		{
			if (tempFinishedInstanceID=tempInstanceID)
			{
				
				;Do some actions
				;MsgBox % tempFinishedInstanceID "-" %tempFinishedInstanceID%_InstanceOfCallingFlow
				;MsgBox % %tempFinishedInstanceID%_CallingFlow
				;MsgBox % %tempFinishedInstanceID%_ElementIDInInstanceOfCallingFlow
				;If the now finished instance was called by another flows that waits for a reply
				if (%tempFinishedInstanceID%_InstanceOfCallingFlow!="" and %tempFinishedInstanceID%_CallingFlow!="" and %tempFinishedInstanceID%_ElementIDInInstanceOfCallingFlow!="")
				{
					tempInstanceToReturn:=%tempFinishedInstanceID%_InstanceOfCallingFlow
					tempElementIDInInstanceToReturn:=%tempFinishedInstanceID%_ElementIDInInstanceOfCallingFlow
					tempCallingFlow:=%tempFinishedInstanceID%_CallingFlow
					;MsgBox %tempCallingFlow%
					;If the calling flow wants to receive the variables
					if %tempFinishedInstanceID%_WhetherToReturVariables!=
					{
						
						tempVariablesToReturn:=v_WriteLocalVariablesToString(tempFinishedInstanceID)
					}
					else
						tempVariablesToReturn=
					
					;Tell the other flow that this instance has finished and eventually return the variables
					ControlSetText,edit1,CalledFlowHasFinished|%tempInstanceToReturn%|%tempElementIDInInstanceToReturn%|%tempVariablesToReturn% ,CommandWindowOfEditor,% "Ѻ" %tempFinishedInstanceID%_CallingFlow
				}
				
				;Clean to free memory
				InstanceIDList.Remove(index1)
				break
			}
		}
			
	}
	
	
	;Loop through the elements that are going to run
	for index3, runElement in goingToRunIDs
	{
		StringSplit, runElement,runElement,_ ;a word like Instance_1_action2_3
		; runElement1 = word "instance"
		; runElement2 = instance id
		; runElement3 = thread
		; runElement4 = element id
		; runElement5 = element id in the instance
		;Insert the element to the list of running elements of the instance
		Instance_%runElement2%_RunningElements.insert(runElement3 "_" runElement4 "_" runElement5)
		
		
		
		;set some variables for correct visual appearance of the element
		if (%runElement4%running<=0)
			%runElement4%running=1
		else
			%runElement4%running++
			
		
		runNeedToRedraw:=true
		
	}
	
	if (runNeedToRedraw=true) ;Draw before the elements are actually executed
	{
		
		UI_draw()
		thread, Priority, -100
	}
	
	
	
	for index3, runElement in goingToRunIDs
	{
		if stopRun=true
			break
		
		
		
		StringSplit, runElement,runElement,_ ;a word like Instance_1_action2_3
		; runElement1 = word "instance"
		; runElement2 = instance id
		; runElement3 = Thread id
		; runElement4 = element id
		; runElement5 = element id in the instance
		; runElement6 = part of the element (only with a loop element)
		
		;Start the elements that are marked as going to run
		tempElementType:=%runElement4%Type
		tempElementSubType:=%runElement4%subType
		
		
		
		Instance_%runElement2%_%runElement3%_%runElement4%_%runElement5%_finishedRunning:=false
		
		;~ MsgBox executing: %runElement%
		if %runElement4%type=loop
			run%tempElementType%%tempElementSubType%(runElement2,runElement3,runElement4,runElement5,runElement6) ;Execute the element
		else
			run%tempElementType%%tempElementSubType%(runElement2,runElement3,runElement4,runElement5) ;Execute the element
		
		
	}
	
	;Detect whether the instance list is empty
	tempTheInstanceListIsNotEmpty=0
	for index1, tempInstanceID in InstanceIDList
	{
		tempTheInstanceListIsNotEmpty++
		break
	}
	;Detect whether there is no instance running anymore
	;ToolTip(tempTheInstanceListIsNotEmpty)
	if (tempTheInstanceListIsNotEmpty=0)
	{
		;ToolTip("Fertig")
		
		stopRun:=true
	}
	
	
	
	;Stop running if needed, else execute this soon again
	if (stopRun=true)
		goto,stopRunning 
	else
		SetTimer,nextRun,-%executionSpeed%,-100
	return
	
	;Stop running
	stopRunning:
	Critical on
	
	SetTimer,nextRun,off
	;Delete all running tags after finishing run
	for index1, element in allElements
	{
		tempstopfunctionname:="stop" %element%type %element%subtype
		%tempstopfunctionname%(element)
		%element%running:=0
	}
	
	InstanceIDList:=Object() ;Remove all Instances
	
	
	ui_draw()

	nowRunning:=false
	r_TellThatFlowIsStopped()
	
	critical off
	return
}
goto,jumpOverExcapeRunLabel



r_startRun:
r_startRun()
return


r_escapeRun:
r_TellThatFlowIsStopping()

stopRun:=true
;Hotkey,esc,off
return

;This timer is used when the a new instance starts and the execution policy says that the old instance has to be stopped
r_WaitUntilStoppedAndThenStart:
if (nowrunning!=true)
{
	r_startRun()
	settimer,r_WaitUntilStoppedAndThenStart,off
}
return

;Those three functions tell the manager about the current status of the flow, set the right text in the GUI elements, and change the icon
r_TellThatFlowIsStopped()
{
	global
	try Menu MyMenu,Rename,% lang("Stopping"),% lang("Run") ;Show run when stopping
	try Menu MyMenu,Rename,% lang("Stop"),% lang("Run")
	try menu, tray, rename, % lang("Stopping"),% lang("Run")
	try menu, tray, rename, % lang("Stop"),% lang("Run")
	ControlSetText,edit1,stopped|%flowName%,CommandWindowOfManager ;Tell the manager that this flow is stopped
	
	if (triggersEnabled=true)
		menu tray,icon,Icons\enabled.ico
	else 
		menu tray,icon,Icons\disabled.ico
}

r_TellThatFlowIsStarted()
{
	global
	try Menu MyMenu,Rename,% lang("Run"),% lang("Stop")  ;Show Stop when running
	try Menu MyMenu,Rename,% lang("Stopping"),% lang("Stop")
	try menu, tray, rename, % lang("Run"),% lang("Stop")
	try menu, tray, rename, % lang("Stopping"),% lang("Stop")
	ControlSetText,edit1,running|%flowName%,CommandWindowOfManager ;Tell the manager that this flow is running
	menu tray,icon,Icons\running.ico
}

r_TellThatFlowIsStopping()
{
	global
	try Menu MyMenu,Rename,% lang("Run"),% lang("Stopping") ;Show Stopping
	try Menu MyMenu,Rename,% lang("Stop"),% lang("Stopping")
	try menu, tray, rename, % lang("Run"),% lang("Stopping")
	try menu, tray, rename, % lang("Stop"),% lang("Stopping")
	ControlSetText,edit1,stopping|%flowName%,CommandWindowOfManager ;Tell the manager that this flow is stopping
	
}
jumpOverExcapeRunLabel:
sleep,1