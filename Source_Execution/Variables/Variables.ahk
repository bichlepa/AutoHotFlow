

LoopVariable_Set(Environment,p_Name,p_Value, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name, p_Value)
	else
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name, p_Value)
	_LeaveCriticalSection()
}
ThreadVariable_Set(Environment,p_Name,p_Value,p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name, p_Value)
	else
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name, p_Value)
	_LeaveCriticalSection()
}
InstanceVariable_Set(Environment,p_Name,p_Value,p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_setInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name, p_Value)
	else
		_setInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name, p_Value)
	_LeaveCriticalSection()
	
}




LoopVariable_Get(Environment,p_Name, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name)
	else
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name)
	_LeaveCriticalSection()
	return value
}
ThreadVariable_Get(Environment,p_Name, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name)
	else
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name)
	_LeaveCriticalSection()
	return value
	
}
InstanceVariable_Get(Environment,p_Name, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		value := _getInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name)
	else
		value := _getInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name)
	_LeaveCriticalSection()
	return value
}


LoopVariable_Delete(Environment,p_Name, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name)
	else
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name)
	_LeaveCriticalSection()
}
ThreadVariable_Delete(Environment,p_Name, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name)
	else
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name)
	_LeaveCriticalSection()
	
}
InstanceVariable_Delete(Environment,p_Name, p_hidden=False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_deleteInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name)
	else
		_deleteInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name)
	_LeaveCriticalSection()
	
}


Var_GetListOfLoopVars(environment)
{
	_EnterCriticalSection()
	retobject := _getThreadPropertyObjectIdList(Environment.InstanceID, Environment.ThreadID, "loopvars")
	_LeaveCriticalSection()
	return retobject
}
Var_GetListOfThreadVars(environment)
{
	_EnterCriticalSection()
	retobject := _getThreadPropertyObjectIdList(Environment.InstanceID, Environment.ThreadID, "threadvars")
	_LeaveCriticalSection()
	return retobject
}
Var_GetListOfInstanceVars(environment)
{
	_EnterCriticalSection()
	retobject := _getInstancePropertyObjectIdList(Environment.InstanceID, "InstanceVars")
	_LeaveCriticalSection()
	return retobject
}
Var_GetListOfAllVars(environment)
{
	_EnterCriticalSection()
	retobject:=Object()
	for index, varname in Var_GetListOfLoopVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfThreadVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfInstanceVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfStaticVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfGlobalVars(environment)
	{
		retobject.push(varname)
	}
	_LeaveCriticalSection()
	return retobject
}


LoopVariable_AddToStack(Environment)
{
	_EnterCriticalSection()
	;Write current loopvars to stack
	; TODO: This code is inefficient
	loopVars := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars")
	loopvarsStack := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStack")
	loopvarsStack.push(loopvars)
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStack", loopvarsStack)

	loopVars := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden")
	loopvarsStack := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStackHidden")
	loopvarsStack.push(loopvars)
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStackHidden", loopvarsStack)
	
	_LeaveCriticalSection()
}
LoopVariable_RestoreFromStack(Environment)
{
	_EnterCriticalSection()
	;Restore loopvars from stack

	; TODO: This code is inefficient
	loopvarsStack := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStack")
	loopVars := loopvarsStack.pop()
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars", loopvars)
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStack", loopvarsStack)

	loopvarsStack := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStackHidden")
	loopVars := loopvarsStack.pop()
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden", loopvars)
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsStackHidden", loopvarsStack)

	_LeaveCriticalSection()
}


Var_RetrieveDestination(p_Name,p_Location)
{
	if (substr(p_Name,1,2)="A_") ;If variable name begins with A_
	{
		if (p_Location!="Thread" and p_Location!="loop")
		{
			return "error_noPermission"
		}
		else ;The variable is either a thread variable or a loop variable
			return p_Location
	}
	else if (p_Location="Thread" or p_Location="loop")
	{
		return "error_NotStartWith_A"
		
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

Var_GetLocation(Environment, p_Name, p_hidden=False)
{
	global AllBuiltInVars, AllCustomBuiltInVars
	_EnterCriticalSection()
	retval:=""
	if (p_hidden = false)
	{
		if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name))
		{
			retval:= "Loop"
		}
		else if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name))
		{
			retval:= "Thread"
		}
		else if (_existsInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name))
		{
			retval:= "instance"
		}
		else ifinstring,AllBuiltInVars, %A_Space%%p_Name%%A_Space%
		{
			retval:= "BuiltIn"
		}
		else ifinstring,AllCustomBuiltInVars, %A_Space%%p_Name%%A_Space%
		{
			retval:= "BuiltIn"
		}
		else if fileexist(_WorkingDir "\Variables\" p_Name ".ahfvd")
		{
			retval:= "global"
		}
		else if fileexist(_WorkingDir "\Variables\"  Environment.flowID "\" p_Name ".ahfvd")
		{
			retval:= "static"
		}
	}
	else
	{
		if (p_hidden != true and p_hidden != "hidden")
		{
			MsgBox unexpected error while retrieving variable location of %p_Name%: The parameter p_hidden has unsupported value: %p_hiden%
		}
		if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name))
		{
			retval:= "Loop"
		}
		else if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name))
		{
			retval:= "Thread"
		}
		else if (_existsInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name))
		{
			retval:= "instance"
		}
	}
	_LeaveCriticalSection()
	return retval
	;~ d(Environment, "error-  " p_name)
	;Todo: static and global variables
}

Var_Set(Environment, p_Name, p_Value, p_Destination="", p_hidden=False)
{
	flowname := _getFlowProperty(Environment.FlowID, "name")
	
	if (isobject(p_Name))
	{
		;todo: allow paths in objects
		p_Name := p_Name.1
	}
	
	res:=Var_CheckName(p_Name, true)
	if (res="empty")
	{
		logger("f0","Setting a variable failed. Its name is empty.", flowname)
		return ;No result
	}
	else if (res="ForbiddenCharacter")
	{
		logger("f0","Setting variable '" p_Name "' failed. It contains forbidden characters.", flowname)
		return ;No result
	}
	
	if (p_Destination="")
		destination:=Var_RetrieveDestination(p_Name, p_Destination)
	else
		destination:=p_Destination
	if (destination!="" and not instr(destination, "error_"))
	{
		%destination%Variable_Set(environment, p_Name, p_Value, p_hidden)
	}
	else
	{
		if (destination = "error_noPermission")
		{
			logger("f0","Setting variable '" p_Name "' failed. No permission.", flowname)
		}
		else if (destination = "error_NotStartWith_A")
		{
			logger("f0","Setting variable '" p_Name "' failed. It does not start with a_.", flowname)
		}
		else
		{
			logger("f0","Setting variable '" p_Name "' failed. Cannot retrieve destination.", flowname)
		}
	}
	;~ d(_execution.instances[Environment.InstanceID].InstanceVars,"instance vars set " p_Name)
}

Var_Get(environment, p_Name, p_hidden = False)
{
	flowname := _getFlowProperty(Environment.FlowID, "name")

	tempvalue= 
	if (p_Name="")
	{
		logger("f0","Retrieving variable failed. The name is empty", flowname)
	}
	if (isobject(p_Name))
	{
		;todo: allow paths in objects
		p_Name := p_Name.1
	}
	
	tempLocation := Var_GetLocation(Environment, p_Name, p_hidden)
	
	;~ d("-" p_Name "-" , p_hidden " --- " tempLocation) 
	if (tempLocation)
	{
		logger("f3","Retrieving " tempLocation " variable '" p_Name "'", flowname)
		tempVar := %tempLocation%Variable_Get(environment, p_Name, p_hidden)
		;~ d(tempVar, tempLocation)
		return tempVar
	}
	else
	{
		logger("f0","Retrieving variable '" p_Name "' failed. It does not exist", flowname)
	}
}

Var_GetType(Environment, p_Name, p_hidden = False)
{
	tempLocation := Var_GetLocation(Environment, p_Name, p_hidden)
	;~ d(tempLocation)
	if (tempLocation)
	{
		variable:=%tempLocation%Variable_Get(Environment, p_Name, p_hidden)
		;~ d(variable)
		if IsObject(variable)
		{
			return "object"
		}
		else
		{
			return "normal"
		}
	}
}

Var_Delete(Environment, p_Name, p_hidden=False)
{
	tempLocation := Var_GetLocation(Environment, p_Name, p_hidden)
	if (tempLocation)
		%tempLocation%Variable_Delete(Environment, p_Name, p_hidden)
}




Var_replaceVariables(environment, p_String, pars = "")
{
	tempstring:=p_String
	;~ d(environment, "replace variables: " p_String )
	Loop
	{
		tempFoundPos:=RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)
		if tempFoundPos=0
			break
		tempVarValue:=Var_Get(environment,tempFoundVarName1)
		;~ d(tempVarValue, tempFoundVarName1)
		if isobject(tempVarValue)
		{
			IfInString, pars, ConvertObjectToString
				tempVarValue := strobj(tempVarValue)
		}
		
		StringReplace,tempstring,tempstring,`%%tempFoundVarName1%`%,% tempVarValue
		;~ MsgBox % "reerhes#-" tempstring "-#-" tempFoundVarName1 "-#-" Variable_Get(p_thread,tempFoundVarName1,p_ContentType)
		;~ MsgBox %tempVariablesToReplace1%
	}
	;~ d(environment, "replace variables result: " tempstring )
	return tempstring 
	
}
