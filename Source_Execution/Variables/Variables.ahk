

LoopVariable_Set(Environment,p_Name,p_Value, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		Environment.loopvarsHidden[p_Name]:=p_Value
	else
		Environment.loopvars[p_Name]:=p_Value
	LeaveCriticalSection(_cs_execution)
}
ThreadVariable_Set(Environment,p_Name,p_Value,p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		Environment.threadvarsHidden[p_Name]:=p_Value
	else
		Environment.threadvars[p_Name]:=p_Value
	LeaveCriticalSection(_cs_execution)
}
InstanceVariable_Set(Environment,p_Name,p_Value,p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		_execution.instances[Environment.InstanceID].InstanceVarsHidden[p_Name]:=p_Value
	else
		_execution.instances[Environment.InstanceID].InstanceVars[p_Name]:=p_Value
	LeaveCriticalSection(_cs_execution)
	
}




LoopVariable_Get(Environment,p_Name, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		return Environment.loopvarsHidden[p_Name]
	else
		return Environment.loopvars[p_Name]
	LeaveCriticalSection(_cs_execution)
}
ThreadVariable_Get(Environment,p_Name, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		return Environment.threadvarsHidden[p_Name]
	else
		return Environment.threadvars[p_Name]
	LeaveCriticalSection(_cs_execution)
	
}
InstanceVariable_Get(Environment,p_Name, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		return _execution.instances[Environment.InstanceID].InstanceVarsHidden[p_Name]
	else
		return _execution.instances[Environment.InstanceID].InstanceVars[p_Name]
	LeaveCriticalSection(_cs_execution)
}


LoopVariable_Delete(Environment,p_Name, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		Environment.loopvarsHidden.delete(p_Name)
	else
		Environment.loopvars.delete(p_Name)
	LeaveCriticalSection(_cs_execution)
}
ThreadVariable_Delete(Environment,p_Name, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		Environment.threadvarsHidden.delete(p_Name)
	else
		Environment.threadvars.delete(p_Name)
	LeaveCriticalSection(_cs_execution)
	
}
InstanceVariable_Delete(Environment,p_Name, p_hidden=False)
{
	EnterCriticalSection(_cs_execution)
	if (p_hidden)
		_execution.instances[Environment.InstanceID].InstanceVarsHidden.delete(p_Name)
	else
		_execution.instances[Environment.InstanceID].InstanceVars.delete(p_Name)
	LeaveCriticalSection(_cs_execution)
	
}


Var_GetListOfLoopVars(environment)
{
	EnterCriticalSection(_cs_execution)
	retobject:=Object()
	for varname, varcontent in Environment.loopvars
	{
		retobject.push(varname)
	}
	LeaveCriticalSection(_cs_execution)
	return retobject
}
Var_GetListOfThreadVars(environment)
{
	EnterCriticalSection(_cs_execution)
	retobject:=Object()
	for varname, varcontent in Environment.threadvars
	{
		retobject.push(varname)
	}
	LeaveCriticalSection(_cs_execution)
	return retobject
}
Var_GetListOfInstanceVars(environment)
{
	EnterCriticalSection(_cs_execution)
	retobject:=Object()
	for varname, varcontent in _execution.instances[Environment.InstanceID].InstanceVars
	{
		retobject.push(varname)
	}
	LeaveCriticalSection(_cs_execution)
	return retobject
}
Var_GetListOfAllVars(environment)
{
	EnterCriticalSection(_cs_execution)
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
	LeaveCriticalSection(_cs_execution)
	return retobject
}


LoopVariable_AddToStack(Environment)
{
	EnterCriticalSection(_cs_execution)
	;Write current loopvars to stack
	Environment.loopvarsStack.push(objFullyClone(Environment.loopvars))
	Environment.loopvarsStackHidden.push(objFullyClone(Environment.loopvarsHidden))
	
	LeaveCriticalSection(_cs_execution)
}
LoopVariable_RestoreFromStack(Environment)
{
	EnterCriticalSection(_cs_execution)
	;Restore loopvars from stack
	Environment.loopvars:=objFullyClone(Environment.loopvarsStack.pop())
	Environment.loopvarsHidden:=objFullyClone(Environment.loopvarsStackHidden.pop())
	
	LeaveCriticalSection(_cs_execution)
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
	EnterCriticalSection(_cs_execution)
	retval:=""
	if (p_hidden = false)
	{
		if (Environment.loopvars.haskey(p_Name))
		{
			retval:= "Loop"
		}
		else if (Environment.threadvars.haskey(p_Name))
		{
			retval:= "Thread"
		}
		else if (_execution.instances[Environment.InstanceID].InstanceVars.haskey(p_Name))
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
		if (Environment.loopvarsHidden.haskey(p_Name))
		{
			retval:= "Loop"
		}
		else if (Environment.threadvarsHidden.haskey(p_Name))
		{
			retval:= "Thread"
		}
		else if (_execution.instances[Environment.InstanceID].InstanceVarsHidden.haskey(p_Name))
		{
			retval:= "instance"
		}
	}
	LeaveCriticalSection(_cs_execution)
	return retval
	;~ d(Environment, "error-  " p_name)
	;Todo: static and global variables
}

Var_Set(Environment, p_Name, p_Value, p_Destination="", p_hidden=False)
{
	if (isobject(p_Name))
	{
		;todo: allow paths in objects
		p_Name := p_Name.1
	}
	
	res:=Var_CheckName(p_Name,true)
	if (res="empty")
	{
		logger("f0","Setting a variable failed. Its name is empty.", Environment.flowname)
		return ;No result
	}
	else if (res="ForbiddenCharacter")
	{
		logger("f0","Setting variable '" p_Name "' failed. It contains forbidden characters.", Environment.flowname)
		return ;No result
	}
	
	if (p_Destination="")
		destination:=Var_RetrieveDestination(p_Name,p_Destination)
	else
		destination:=p_Destination
	if (destination!="" and not instr(destination, "error_"))
	{
		%destination%Variable_Set(environment,p_Name,p_Value,p_hidden)
	}
	else
	{
		if (destination = "error_noPermission")
		{
			logger("f0","Setting variable '" p_Name "' failed. No permission.", Environment.flowname)
		}
		else if (destination = "error_NotStartWith_A")
		{
			logger("f0","Setting variable '" p_Name "' failed. It does not start with a_.", Environment.flowname)
		}
		else
		{
			logger("f0","Setting variable '" p_Name "' failed. Cannot retrieve destination.", Environment.flowname)
		}
	}
	;~ d(_execution.instances[Environment.InstanceID].InstanceVars,"instance vars set " p_Name)
}

Var_Get(environment, p_Name, p_hidden = False)
{
	tempvalue= 
	if (p_Name="")
	{
		logger("f0","Retrieving variable failed. The name is empty", Environment.flowname)
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
		logger("f3","Retrieving " tempLocation " variable '" p_Name "'", Environment.flowname)
		tempVar := %tempLocation%Variable_Get(environment, p_Name, p_hidden)
		;~ d(tempVar, tempLocation)
		return tempVar
	}
	else
	{
		logger("f0","Retrieving variable '" p_Name "' failed. It does not exist", Environment.flowname)
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
