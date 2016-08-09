

;Here at the top there will be something like this line:
; share:=Criticalobject(1234)
;The object share contains values which are shared among this and other threads
#NoTrayIcon
#Persistent
#include language\language.ahk ;Must be very first
#include threads\d_Debug.ahk

#include External Scripts\Object to file\String-object-file.ahk


#include elements\actions\New_Variable.ahk ;First element in Category variables
#include elements\actions\Traytip.ahk
#include elements\functions for elements.ahk


parentThread:=AhkExported()

currentExec:=[]
currentExec.state:="idle"
;initialize languages
lang_FindAllLanguages()
;~ MsgBox ioashfiop
extern_changeDetected()
{
	global
	ToolTip change
	if (currentExec.state!="idle")
		return
	else
		settimer,r_Iteration,-10
	
}



r_Iteration()
{
	;~ MsgBox r_Iteration
	global FlowLastActivity, runNeedToRedraw, allInstances, allThreads, allElements, allConnections, allTriggers, currentExec, CriticalSectionAllInstances
	;~ global currentStateID, states
	
	FlowLastActivity:=a_now
	runNeedToRedraw:=false
	
	ToolTip, iteration
	
	;~ EnterCriticalSection(CriticalSectionAllInstances)
	currentExec.thread:=""
	;~ d(allThreads,646)
	
	;Search for a pending thread
	for forThreadID, forThread in allThreads
	{
		;~ d(forthread,8616846)
		if (forThread.state="pending") ;Element of thread is ready to be executed
		{
			;Execute element
			logger("f3","Proceeding thread " forThreadID)
			currentExec.thread:=forThreadID
			allThreads[currentExec.thread].state:="running"
			currentExec.state:="running"
			currentExec.element:=forthread.element
			currentExec.ClonedElement:=allElements[forthread.element].clone()
			;~ LeaveCriticalSection(CriticalSectionAllInstances)
			SetTimer,r_ExecuteElement,-10 
			break
		}
		if (forThread.state="finished") ;Element of thread is has finished
		{
			;Find next element
			logger("f3","Proceeding thread " forThreadID)
			currentExec.state:="finished"
			currentExec.element:=forthread.element
			currentExec.thread:=forThreadID
			;~ LeaveCriticalSection(CriticalSectionAllInstances)
			r_FindNextElements()
			r_OnChange()
			break
		}
	}
	
	
}


r_FindNextElements()
{
	
	global FlowLastActivity, runNeedToRedraw, share, allInstances, allThreads, allElements, allConnections, allTriggers, currentExec
	ToolTip,findnext
	
	;~ d(allElements)
	;~ d(currentExec.stateID " - " share.currentStateID)
	;~ d(currentExec)
	;~ d(share)
	;When starting an iteration, a copy will be made of the current state. This will prevent data inconsistency if user changes something during execution
	if (share.currentStateID != currentExec.stateID)
	{
		logger("f3","Copying current state " currentStateID " for execution")
		;~ d("Copying current state " currentStateID " for execution")
		
		currentExec.stateID:=share.currentStateID
		currentExec.allElements:=ObjFullyClone(allElements)
		currentExec.allConnections:=ObjFullyClone(allConnections)
		currentExec.allTriggers:=ObjFullyClone(allTriggers)
		currentExec.flowSettings:=ObjFullyClone(share.flowSettings)
		
		
		;~ currentExec.state:=ObjFullyClone(states[currentStateID])
		
		;Write to all element the information, which connections start from them. this will make things easier later
		for forID, forElement in currentExec.allConnections
		{
			;~ d(currentExec.state.allConnections,145)
			;~ d(currentExec.state.allElements,2431)
			
			if (not IsObject(currentExec.allElements[forElement.from].To))
			{
				;~ d(forElement,16234)
				currentExec.allElements[forElement.from].To:=[]
			}
			currentExec.allElements[forElement.from].To.push(forElement.id)
			;~ d(currentExec.state.allElements[forElement.from],14)
		}
	}
	
	;~ EnterCriticalSection(CriticalSectionAllInstances)
	
	result:=allThreads[currentExec.thread].lastResult
	allThreads[currentExec.thread].lastResult:=""
	;Find next element
	
	ConnectionFound:=0
	;~ d(currentExec,"hioawefhio")
	;Go through all connections which start at the current element
	for forConnectionIndex, forConnectionID in currentExec.allElements[currentExec.element].to
	{
		tempConnection:=currentExec.allConnections[forConnectionID]
		;~ d(tempConnection,"1h")
		;~ d(tempConnection.connectiontype "-" result,"541h")
		if (tempConnection.connectiontype=result) ;If the result of the execution is the same as the connection type
		{
			;~ d(tempConnection,465655464651)
			ConnectionFound++
			
			if (ConnectionFound=1) ;If it is the first connection which was found
			{
				tempThread:=currentExec.thread
				logger("f3","Found connection to '" tempConnection.to "'")
			}
			else ;If more than one connection was found
			{
				;~ d(forthread,56)
				;Clone the thread
				tempThread:=Thread_Clone(currentExec.thread)
				;~ d(tempThread,5678)
				logger("f3","Found connection to " tempConnection.to "'. New thread created: '" tempThread.id "'")
			}
			
			;Assign the element of the thread
			allThreads[tempThread].element:=currentExec.allElements[tempConnection.to]
			
			
			;update variables for drawing
			allelements[allThreads[tempThread].element].state:="pending"
			allConnections[forConnectionID].lastRun:=a_tickcount
			
			ui_draw()
			
			;TODO: prepare entering and leaving a loop
			
			
			;The thread is now pending and is ready to execute
			allThreads[tempThread].state:="pending"
			
			;~ MsgBox agrar
		}
		
		
	}
	
	if (ConnectionFound=0) ;If no matching connection found
	{
		;End thread
		d("remove thread " currentExec.thread,1)
		logger("f3","No suitablee connection found. Thread " currentExec.thread " ends")
		Thread_Remove(currentExec.thread)
		
		
		if (allInstances[allThreads[currentExec.thread].instance].threads.count()=0)
		{
			;~ d("herhwe",1)
			instance.delete(allThreads[currentExec.thread].instance)
			logger("f3","Closing " allThreads[currentExec.thread].instance " because all its threads eneded")
			
			if (allInstances.count()=0)
			{
				logger("f3","All instances finished")
				currentExec.running:=false
			}
			
		}
		
	}
	
	;~ LeaveCriticalSection(CriticalSectionAllInstances)
	
}

r_ExecuteElement()
{
	global FlowLastActivity, runNeedToRedraw, allInstances, allThreads, allElements, allConnections, allTriggers, currentExec
	
	
	tempElementType:=currentExec.ClonedElement.type
	tempElementSubType:=currentExec.ClonedElement.subtype
	ToolTip,execute %tempElementType% %tempElementSubType%
	
	logger("f3","Executing " tempElementType " '" tempElementSubType "'")
	currentExec.execution:=new %tempElementType%%tempElementSubType%(currentExec.thread,currentExec.ClonedElement)
	currentExec.execution.run()
	
}

r_ElementFinished(result)
{
	global FlowLastActivity, runNeedToRedraw, allInstances, allThreads, allElements, allConnections, allTriggers, currentExec
	allelements[currentExec.element].isRunning:=false
	allelements[currentExec.element].lastRun:=a_tickcount
	allThreads[currentExec.thread].lastResult:=result
	logger("f3","element " currentExec.element " ended with result '" result "'")
	if (result="Exception")
	{
		;TODO, error message
		;~ d(forThread.execution,"8446516")
	}
	ui_draw()
	r_FindNextElements()
}

r_OnChange()
{
	parentThread.ahkFunction("r_OnChange")
}
ui_draw()
{
	parentThread.ahkFunction("ui_draw")
	
}
logger(par1,par2)
{
	parentThread.ahkFunction("logger",par1,par2)
}

Thread_Clone(p_ID)
{
	global 
	parentThread.ahkFunction("Thread_Clone",p_ID)
}

Thread_Remove(p_ID)
{
	global 
	ToolTip remove thread %p_id%
	parentThread.ahkFunction("Thread_Remove",p_ID)
}



AllBuiltInVars:="-A_Space-A_Tab-A_YYYY-A_Year-A_MM-A_Mon-A_DD-A_MDay-A_MMMM-A_MMM-A_DDDD-A_DDD-A_WDay-A_YDay-A_Hour-A_Min-A_Sec-A_MSec-A_TickCount-A_TimeIdle-A_TimeIdlePhysical-A_Temp-A_OSVersion-A_Is64bitOS-A_PtrSize-A_Language-A_ComputerName-A_UserName-A_ScriptDir-A_WinDir-A_ProgramFiles-A_AppData-A_AppDataCommon-A_Desktop-A_DesktopCommon-A_StartMenu-A_StartMenuCommon-A_Programs-A_ProgramsCommon-A_Startup-A_StartupCommon-A_MyDocuments-A_IsAdmin-A_ScreenWidth-A_ScreenHeight-A_ScreenDPI-A_IPAddress1-A_IPAddress2-A_IPAddress3-A_IPAddress4-A_Cursor-A_CaretX-A_CaretY-----" ;a_now and a_nowutc not included, they will be treated specially
 


ThreadVariable_Set(p_Thread,p_Name,p_Value,p_ContentType="Normal")
{
	allThreads[p_thread].vars[p_Name]:=CriticalObject({name:p_Name,value:p_Value,type:p_ContentType})
}
LoopVariable_Set(p_Thread,p_Name,p_Value,p_ContentType="Normal")
{
	allThreads[p_thread].loopvars[p_Name]:=CriticalObject({name:p_Name,value:p_Value,type:p_ContentType})
}
InstanceVariable_Set(p_Thread_OR_Instance,p_Name,p_Value,p_ContentType="Normal")
{
	IfInString,p_Thread_OR_Instance,thread
	{
		allInstances[allThreads[p_Thread_OR_Instance].instance].vars[p_Name]:=CriticalObject({name:p_Name,value:p_Value,type:p_ContentType})
	}
	else
	{
		allInstances[p_Thread_OR_Instance].vars[p_Name]:=CriticalObject({name:p_Name,value:p_Value,type:p_ContentType})
	}
}

StaticVariable_Set(p_Thread,p_Name,p_Value,p_ContentType="Normal")
{
	;~ allThreads[p_thread].loopvars[p_Name]:=CriticalObject({name=p_Name,value=p_Value,type=p_ContentType})
}
GlobalVariable_Set(p_Thread,p_Name,p_Value,p_ContentType="Normal")
{
	;~ allThreads[p_thread].loopvars[p_Name]:=CriticalObject({name=p_Name,value=p_Value,type=p_ContentType})
}

Variable_Set(p_Thread,p_Name,p_Value,p_ContentType="Normal",p_Destination="")
{
	if (p_Destination="")
		destination:=Variable_RetrieveDestination(p_Name,p_Destination,"LOG")
	else
		destination:=p_Destination
	if (destination!="")
	{
		%destination%Variable_Set(p_Thread,p_Name,p_Value,p_ContentType)
	}
}

Variable_RetrieveDestination(p_Name,p_Location,p_log=true)
{
	;Check whether the variable name is valid
	res:=Variable_CheckName(p_Name,true)
	if (res="empty")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting a variable failed. Its name is empty.")
		return ;No result
	}
	else if (res="ForbiddenCharacter")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting variable '" p_Name "' failed. It contains forbidden characters.")
		return ;No result
	}
	
	
	if (substr(p_Name,1,2)="A_") ;If variable name begins with A_
	{
		if (p_Location!="Thread" and p_Location!="loop")
		{
			if (p_log=true or p_log="LOG")
				logger("f0","Setting built in variable '" p_Name "' failed. No permission given.")
			return ;No result
		}
		else ;The variable is either a thread variable or a loop variable
			return "thread"
	}
	else if (p_Location="Thread" or p_Location="loop")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting built in variable '" p_Name "' failed. It does not start with 'A_'.")
		return ;No result
		
	}
	else if (substr(p_Name,1,7)="global_")  ;If variable is global
	{
		return "global"
	}
	else if (substr(p_Name,1,7)="static_") ;If variable is static
	{
		return "static"
	}
	else
	{
		return "instance"
	}
	
	
}


Variable_CheckName(p_Name, tellWhy=false) ;Return 1 if valid. 0 if not
{
	;Check whether the variable name is not empty
	if p_Name=
	{
		;~ logger("f0","Setting a variable failed. Its name is empty.")
		if tellWhy
			return "Empty"
		else
			return 0
	}
	;Check whether the variable name is valid and has no prohibited characters
	try
		asdf%p_Name%:=1 
	catch
	{
		;~ logger("f0","Setting variable '" p_Name "' failed. Name is invalid.")
		if tellWhy
			return "ForbiddenCharacter"
		else
			return 0
	}
	if tellWhy
		return "OK"
	else
		return 1
}


Variable_Get(p_Thread,p_Name,p_ContentType="Normal")
{
	if (p_Name="")
	{
		logger("f0","Retrieving variable failed. The name is empty")
	}
	else if (substr(p_Name,1,2)="A_") ; if variable is a built in variable or a thread variable
	{
		;~ MsgBox asfh  %name%
		if (p_thread.vars.HasKey(p_Name)) ;Try to find a thread variable
		{
			logger("f3","Retrieving thread variable '" p_Name "'")
			tempvalue:=p_thread.vars[p_Name].value
			;~ MsgBox ag e %tempvalue%
			return tempvalue
		}
		else if (p_thread.loopvars.HasKey(p_Name)) ;Try to find a loop variable
		{
			logger("f3","Retrieving loop variable '" p_Name "'")
			tempvalue:=p_thread.loopvars[p_Name].value
			return tempvalue
		}
		;If no thread and loop variable found, try to find a built in variable
		else if (p_Name="a_now" || p_Name="A_NowUTC")
		{
			
			if (VariableType="Normal")
			{
				tempvalue:=this.convertVariable(p_Name,"date")
				
				return tempvalue
			}
			else
			{
				tempvalue:=%p_Name%
				;~ MsgBox %tempvalue%
				return tempvalue
			}
		}
		else if (p_Name="A_YWeek") ;Separate the week.
		{
			StringRight,tempvalue,A_YWeek,2
			return tempvalue
		}
		else if (p_Name="A_LanguageName") 
		{
			tempvalue:= ;GetLanguageNameFromCode(A_Language) ;;TODO: Uncomment
			
			return tempvalue
		}
		else if (p_Name="a_workingdir")
		{
			tempvalue:=flowSettings.WorkingDir
			return tempvalue
		}
		;~ else if (name="a_triggertime")
		;~ {
			;~ tempvalue:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[name] 
			;~ if VariableType=Normal
				;~ return this.convertVariable(tempvalue,"date","`n") 
			;~ else
			;~ {
				;~ return tempvalue
			;~ }
		;~ }
		else if (p_Name="a_linefeed" or p_Name="a_lf")
		{
			return "`n"
		}
		;~ else if (p_Name="a_CPULoad")
		;~ {
			;~ return CPULoad()
		;~ }
		;~ else if (p_Name="a_MemoryUsage")
		;~ {
			;~ return MemoryLoad()
		;~ }
		;~ else if (p_Name="a_OSInstallDate")
		;~ {
			;~ if VariableType=Normal
				;~ return convertVariable(OSInstallDate(),"date","`n") 
			;~ else
			;~ {
				;~ return OSInstallDate()
			;~ }
		;~ }
		else If InStr(this.AllBuiltInVars,"-" p_Name "-")
		{
			tempvalue:=%p_Name%
			return tempvalue
		}
		else
		{
			logger("f0","Retrieving variable '" p_Name "' failed. It does not exist")
		}
			
			
	}
	else ;If this is a instance variable
	{
		;~ d(p_thread.instance.vars,name)
		if (allInstances[allThreads[p_thread].instance].vars.HasKey(p_Name)) ;Try to find a local variable
		{
			logger("f3","Retrieving instance variable '" p_Name "'")
			tempvalue:=allInstances[allThreads[p_thread].instance].vars[p_Name].value
			;TODO, convert type if necessary
			;~ MsgBox ag e %tempvalue% - %name%
			return tempvalue
		}
		else
		{
			logger("f0","Retrieving instance variable '" p_Name "' failed. It does not exist")
		}
	}
	
}

replaceVariables(p_thread,p_String,p_ContentType="asis")
{
	tempstring:=p_String
	Loop
	{
		tempFoundPos:=RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)
		if tempFoundPos=0
			break
		StringReplace,tempstring,tempstring,`%%tempFoundVarName1%`%,% Variable_Get(p_thread,tempFoundVarName1,p_ContentType)
		;~ MsgBox % "reerhes#-" tempstring "-#-" tempFoundVarName1 "-#-" Variable_Get(p_thread,tempFoundVarName1,p_ContentType)
		;~ MsgBox %tempVariablesToReplace1%
	}
	return tempstring 
	
}

Variable_Convert(p_Value,p_Contenttype,p_TargetType)
{
	if (p_TargetType="normal")
	{
		if (p_Contenttype="date")
		{
			FormatTime,result,% p_Value
		}
		else if (p_Contenttype="list")
		{
			if IsObject(p_Value)
				result:=strobj(p_Value)
			else
				result:= p_Value
			
		}
	}
	
	return result
}


/* Evaluation of an Expression
*/
EvaluateExpression(p_Thread,ExpressionString)
{
	logger("f3","Evaluating expression " ExpressionString)
	
	ExpressionString:=A_Space replaceVariables(p_Thread,ExpressionString) A_Space
	
	StringReplace,ExpressionString,ExpressionString,>=,≥,all
	StringReplace,ExpressionString,ExpressionString,<=,≤,all
	StringReplace,ExpressionString,ExpressionString,!=,≠,all
	StringReplace,ExpressionString,ExpressionString,<>,≠,all
	StringReplace,ExpressionString,ExpressionString,==,≡,all
	StringReplace,ExpressionString,ExpressionString,% " or ",∨,all
	StringReplace,ExpressionString,ExpressionString,||,∨,all
	StringReplace,ExpressionString,ExpressionString,% " and ", ∧,all
	StringReplace,ExpressionString,ExpressionString,&&,∧,all
	StringReplace,ExpressionString,ExpressionString,% " not ",% " ¬",all
	StringReplace,ExpressionString,ExpressionString,% "!",% "¬",all
	return v_EvaluateExpressionRecurse(p_Thread,ExpressionString)
}

/* Evaluation of an Expression
Thanks to Sunshine for the easy to understand instruction. See http://www.sunshine2k.de/coding/java/SimpleParser/SimpleParser.html
If anybody knows how to implement more operands and make this more flexible, or even support scripts, please contribute!
*/
v_EvaluateExpressionRecurse(p_Thread,ExpressionString)
{
	;MsgBox %ExpressionString%
	
	
	ExpressionString:=trim(ExpressionString)
	
	if (substr(ExpressionString,1,1)="-" or substr(ExpressionString,1,1)="+")
		ExpressionString:="0" ExpressionString
	
	
	if (v_SearchForFirstOperand(ExpressionString,FoundOpreand,leftSubstring,rightSubstring))
	{
		;MsgBox %  leftSubstring FoundOpreand rightSubstring 
		if ( FoundOpreand != "¬")
			resleft:= v_EvaluateExpressionRecurse(p_Thread,leftSubstring)
		resright:=v_EvaluateExpressionRecurse(p_Thread,rightSubstring)
		;MsgBox %FoundOpreand% %resleft% %resright%
		if FoundOpreand = +
			return resleft + resright
		else if FoundOpreand = -
			return resleft - resright
		else if FoundOpreand = *
			return resleft * resright
		else if FoundOpreand = /
			return resleft / resright
		else if FoundOpreand = ≠
			return resleft != resright
		else if FoundOpreand = ≡
			return resleft == resright
		else if FoundOpreand = =
			return resleft = resright
		else if FoundOpreand = ≤
			return resleft <= resright
		else if FoundOpreand = ≥
			return resleft >= resright
		else if FoundOpreand = <
			return resleft < resright
		else if FoundOpreand = >
			return resleft > resright
		else if FoundOpreand = ∨
			return resleft || resright
		else if FoundOpreand = ∧
			return resleft && resright
		else if FoundOpreand = ¬
		{
			return not resright
		}
		else
			return
	}
	
	if (substr(ExpressionString,1,1) = "(")
	{
		StringRight,tempchar,ExpressionString,1
		if (tempchar = ")")
		{
			StringTrimLeft,ExpressionString,ExpressionString,1
			StringTrimRight,ExpressionString,ExpressionString,1
			return (v_EvaluateExpressionRecurse(p_Thread,ExpressionString))
		}
		   
		else
		{
			MsgBox Bracket Error
			return
		}
	}
	
	if ExpressionString is number
		return ExpressionString
	
	return Variable_Get(p_Thread,ExpressionString,"asIs")
	
	
}

v_SearchForFirstOperand(String,ByRef ResFoundoperand,Byref ResLeftString, Byref ResRightString)
{
	BracketCount=0
	firstplus=
	firstminus=
	;MsgBox %String%
	loop, parse, String
	{
		
		if (a_Loopfield="(")
		{
			BracketCount++
		}
		else if (a_Loopfield=")")
		{
			BracketCount--
		}
		else if (BracketCount=0)
		{
			if (a_Loopfield="∨")
			{
				firstor:=A_Index
			}
			if (a_Loopfield="∧")
			{
				firstand:=A_Index
			}
			if (a_Loopfield="¬")
			{
				
				firstnot:=A_Index
			}
			if (a_Loopfield="=")
			{
				firstequal:=A_Index
				firstequaletc:=A_Index
			}
			if (a_Loopfield="≡")
			{
				firstequalequal:=A_Index
				firstequaletc:=A_Index
			}
			if (a_Loopfield="≠")
			{
				firstenotequal:=A_Index
				firstequaletc:=A_Index
			}
			if (a_Loopfield=">" )
			{
				firstgreater:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="<" )
			{
				firstsmaller:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="≥" )
			{
				firstgreaterequal:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="≤" )
			{
				firstsmallerequal:=A_Index
				firstgreatersmaller:=A_Index
			}
			if (a_Loopfield="+")
			{
				firstplus:=A_Index
				firstplusminus:=A_Index
			}
			if (a_Loopfield="+" )
			{
				firstplus:=A_Index
				firstplusminus:=A_Index
			}
			if (a_Loopfield="-" )
			{
				firstminus:=A_Index
				firstplusminus:=A_Index
			}
			if (a_Loopfield="*" )
			{
				firstMult:=A_Index
				firstplusMultDiv:=A_Index
			}
			if (a_Loopfield="/")
			{
				firstDiv:=A_Index
				firstplusMultDiv:=A_Index
			}
		}
		
		
	}
	
	if (firstor!="" )
	{
		
		ResFoundoperand:="∨"
		StringLeft,ResLeftString,String,% firstor -1
		StringTrimLeft,ResRightString,String,% firstor
		
		return true
	}
	if (firstand!="")
	{
		
		ResFoundoperand:="∧"
		StringLeft,ResLeftString,String,% firstand -1
		StringTrimLeft,ResRightString,String,% firstand
		
		return true
	}
	if (firstnot!="")
	{
		
		ResFoundoperand:="¬"
		StringLeft,ResLeftString,String,% firstnot -1
		StringTrimLeft,ResRightString,String,% firstnot
		
		return true
	}
	if (firstgreater!="" and (firstgreater =firstgreatersmaller))
	{
		
		ResFoundoperand:=">"
		StringLeft,ResLeftString,String,% firstgreater -1
		StringTrimLeft,ResRightString,String,% firstgreater
		
		return true
	}
	if (firstsmaller!="" and (firstsmaller =firstgreatersmaller))
	{
		
		ResFoundoperand:="<"
		StringLeft,ResLeftString,String,% firstsmaller -1
		StringTrimLeft,ResRightString,String,% firstsmaller
		
		return true
	}
	if (firstgreaterequal!="" and (firstgreaterequal =firstgreatersmaller))
	{
		
		ResFoundoperand:="≥"
		StringLeft,ResLeftString,String,% firstgreaterequal -1
		StringTrimLeft,ResRightString,String,% firstgreaterequal
		
		return true
	}
	if (firstsmallerequal!="" and (firstsmallerequal =firstgreatersmaller))
	{
		
		ResFoundoperand:="≤"
		StringLeft,ResLeftString,String,% firstsmallerequal -1
		StringTrimLeft,ResRightString,String,% firstsmallerequal
		
		return true
	}
	if (firstequal!="" and (firstequal =firstequaletc))
	{
		
		ResFoundoperand:="="
		StringLeft,ResLeftString,String,% firstequal -1
		StringTrimLeft,ResRightString,String,% firstequal
		
		return true
	}
	if (firstequalequal!="" and (firstequalequal =firstequaletc))
	{
		
		ResFoundoperand:="≡"
		StringLeft,ResLeftString,String,% firstequalequal -1
		StringTrimLeft,ResRightString,String,% firstequalequal
		
		return true
	}
	if (firstenotequal!="" and (firstenotequal =firstequaletc))
	{
		
		ResFoundoperand:="≠"
		StringLeft,ResLeftString,String,% firstenotequal -1
		StringTrimLeft,ResRightString,String,% firstenotequal
		
		return true
	}
	if (firstplus!="" and (firstplus =firstplusminus))
	{
		
		ResFoundoperand=+
		StringLeft,ResLeftString,String,% firstplus -1
		StringTrimLeft,ResRightString,String,% firstplus
		
		return true
	}
	if (firstminus!=""  and (firstminus =firstplusminus))
	{
		ResFoundoperand=-
		StringLeft,ResLeftString,String,% firstminus -1
		StringTrimLeft,ResRightString,String,% firstminus
		return true
	}
	if (firstMult!="" and (firstMult = firstplusMultDiv))
	{
		
		ResFoundoperand=*
		StringLeft,ResLeftString,String,% firstMult -1
		StringTrimLeft,ResRightString,String,% firstMult
		
		return true
	}
	if (firstDiv!="" and (firstDiv = firstplusMultDiv))
	{
		ResFoundoperand=/
		StringLeft,ResLeftString,String,% firstDiv -1
		StringTrimLeft,ResRightString,String,% firstDiv
		return true
	}
	
	;MsgBox No operand found in "%String%" firstplus %firstplus% firstminus %firstminus% firstplusminus %firstplusminus%
	return false
	
}




ObjFullyClone(obj) ;Thanks to fincs
{
	nobj := obj.Clone()
	for k,v in nobj
		if IsObject(v)
			nobj[k] := A_ThisFunc.(v)
	return nobj
}


