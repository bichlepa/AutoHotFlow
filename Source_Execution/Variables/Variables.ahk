; file for handling of variables of type loop, thread, instance

; variables can be hidden, that means that they are not visible if user tries to access it manually.
; some elements can use hidden variables in order to protect the values from (unintended or intended) changes by user.
; example for usage of hidden variables are in "lopp_work_through_a_list", as well as "action_trace_point" and "action_trace_point_check".


; set a loop variable which is only visible inside a loop
LoopVariable_Set(Environment, p_Name, p_Value, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name, p_Value)
	else
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name, p_Value)
	_LeaveCriticalSection()
}
; set a thread variable which is only visible inside a thread
ThreadVariable_Set(Environment, p_Name, p_Value, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name, p_Value)
	else
		_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name, p_Value)
	_LeaveCriticalSection()
}
; set an instance variable which is visible inside all threads of an instance
InstanceVariable_Set(Environment, p_Name, p_Value, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_setInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name, p_Value)
	else
		_setInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name, p_Value)
	_LeaveCriticalSection()
}

; get the value of a loop variable
LoopVariable_Get(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name)
	else
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name)
	_LeaveCriticalSection()
	return value
}
; get the value of a thread variable
ThreadVariable_Get(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name)
	else
		value := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name)
	_LeaveCriticalSection()
	return value
}
; get the value of an instance variable
InstanceVariable_Get(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		value := _getInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name)
	else
		value := _getInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name)
	_LeaveCriticalSection()
	return value
}

; delete a loop variable
LoopVariable_Delete(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name)
	else
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name)
	_LeaveCriticalSection()
}
; delete a thread variable
ThreadVariable_Delete(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name)
	else
		_deleteThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name)
	_LeaveCriticalSection()
}
; delete an instance variable
InstanceVariable_Delete(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	if (p_hidden)
		_deleteInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name)
	else
		_deleteInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name)
	_LeaveCriticalSection()
}

; get list of all (not hidden) loop variables (in current thread)
Var_GetListOfLoopVars(environment)
{
	_EnterCriticalSection()
	retobject := _getThreadPropertyObjectIdList(Environment.InstanceID, Environment.ThreadID, "loopvars")
	_LeaveCriticalSection()
	return retobject
}
; get list of all (not hidden) thread variables (in current thread)
Var_GetListOfThreadVars(environment)
{
	_EnterCriticalSection()
	retobject := _getThreadPropertyObjectIdList(Environment.InstanceID, Environment.ThreadID, "threadvars")
	_LeaveCriticalSection()
	return retobject
}
; get list of all (not hidden) instance variables (in current instance)
Var_GetListOfInstanceVars(environment)
{
	_EnterCriticalSection()
	retobject := _getInstancePropertyObjectIdList(Environment.InstanceID, "InstanceVars")
	_LeaveCriticalSection()
	return retobject
}
; get list of all (not hidden) accessible variables (without buit-in variables)
Var_GetListOfAllVars(environment)
{
	_EnterCriticalSection()
	; prepare list, which will contain the variable names
	retobject := Object()
	
	; get all loop variables
	tempVarsList := Var_GetListOfLoopVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(tempVarsList)
	}
	; get all thread variables
	tempVarsList := Var_GetListOfThreadVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(varname)
	}
	; get all instance variables
	tempVarsList := Var_GetListOfInstanceVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(varname)
	}
	; get all static variables
	tempVarsList := Var_GetListOfStaticVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(varname)
	}
	; get all global variables
	tempVarsList := Var_GetListOfGlobalVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(varname)
	}
	_LeaveCriticalSection()
	return retobject
}

; pushes current loop variables to stack
; we can have loops inside loops. So we have to create a set of loop variables in outer loop,
;   then, when entering the innser loop, hide the variables of the outer loop and then create new variables.
;   The variables of outer loop won't be accessible from inner loop.
;   When leaving the inner loop, we have to make the variables of the outer loop visible.
LoopVariable_AddToStack(p_InstanceID, p_ThreadID)
{
	_EnterCriticalSection()
	;Write current loopvars to stack
	; TODO: This code is inefficient
	loopVars := _getThreadProperty(p_InstanceID, p_ThreadID, "loopvars")
	loopvarsStack := _getThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStack")
	loopvarsStack.push(loopvars)
	_setThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStack", loopvarsStack)

	;also, write hidden loopvars to stack
	loopVars := _getThreadProperty(p_InstanceID, p_ThreadID, "loopvarsHidden")
	loopvarsStack := _getThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStackHidden")
	loopvarsStack.push(loopvars)
	_setThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStackHidden", loopvarsStack)
	
	_LeaveCriticalSection()
}

; restore loop variables from stack (when leaving an inner loop)
LoopVariable_RestoreFromStack(p_InstanceID, p_ThreadID)
{
	_EnterCriticalSection()

	; TODO: This code is inefficient

	;Restore loopvars from stack
	loopvarsStack := _getThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStack")
	loopVars := loopvarsStack.pop()
	_setThreadProperty(p_InstanceID, p_ThreadID, "loopvars", loopvars)
	_setThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStack", loopvarsStack)

	;also, restore hidden loopvars from stack
	loopvarsStack := _getThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStackHidden")
	loopVars := loopvarsStack.pop()
	_setThreadProperty(p_InstanceID, p_ThreadID, "loopvarsHidden", loopvars)
	_setThreadProperty(p_InstanceID, p_ThreadID, "loopvarsStackHidden", loopvarsStack)

	_LeaveCriticalSection()
}

; find out the location of a variable from name (before setting a variable)
; p_Location: can be empty, then the possible location is either global, static or instance
;    p_Location can be "thread" or "loop", then it will return "thread" or "loop" if the variable name starts with "A_"
; more about the variable location in comment for Var_Set()
Var_RetrieveDestination(p_Name, p_Location)
{
	if (substr(p_Name, 1, 2) = "A_") ;If variable name begins with A_
	{
		; variables which start wich "A_" are either thread, loop or built-in.
		if (p_Location != "Thread" and p_Location != "loop")
		{
			; the location is not "thread" or "loop". So the variable name must not start with "A_"
			return "error_noPermission"
		}
		else ;The variable is either a thread variable or a loop variable
			return p_Location
	}
	else if (p_Location = "Thread" or p_Location = "loop")
	{
		; the variable does not start with "A_", so it can't have location "thread" or "loop"
		return "error_NotStartWith_A"
	}
	else if (substr(p_Name, 1, 7) = "global_")  ;If variable is global
	{
		return "global"
	}
	else if (substr(p_Name, 1, 7) = "static_") ;If variable is static
	{
		return "static"
	}
	else
	{
		; a variable which has no prefix is always an instance variable
		return "instance"
	}
}

; get location of an existing variable
Var_GetLocation(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()

	if (isobject(p_Name))
	{
		throw exception("p_Name is an object")
	}

	retval := "" ; initialize empty return value

	if (not p_hidden) ; if variable is not hidden
	{
		if (substr(p_Name, 1, 2) = "A_") ;If variable name begins with A_
		{
			; search for a loop variable with that name
			if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvars." p_Name))
			{
				retval := "Loop"
			}
			; search for a thread variable with that name
			else if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvars." p_Name))
			{
				retval := "Thread"
			}
			; search for a build-in variable with that name (with same name as in AHK)
			else ifinstring, global_AllBuiltInVars, %A_Space%%p_Name%%A_Space%
			{
				retval := "BuiltIn"
			}
			; search for a custom build-in variable with that name (which does not exist in AHK or has different value)
			else ifinstring, global_AllCustomBuiltInVars, %A_Space%%p_Name%%A_Space%
			{
				retval := "BuiltIn"
			}
		}
		else if (substr(p_Name, 1, 7) = "global_")  ;If variable is global
		{
			; search for a global variable with that name
			if fileexist(_WorkingDir "\Variables\" p_Name ".ahfvd")
			{
				retval:= "global"
			}
		}
		else if (substr(p_Name, 1, 7) = "static_") ;If variable is static
		{
			; search for a static variable with that name
			if fileexist(_WorkingDir "\Variables\"  Environment.flowID "\" p_Name ".ahfvd")
			{
				retval:= "static"
			}
		}
		Else ; if variable has no prefix, it can only be an instance variable
		{
			; search for an intance variable with that name
			if (_existsInstanceProperty(Environment.InstanceID, "InstanceVars." p_Name))
			{
				retval := "instance"
			}
		}
	}
	else
	{
		if (substr(p_Name, 1, 2) = "A_") ;If variable name begins with A_
		{
			; search for a loop variable with that name
			if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "loopvarsHidden." p_Name))
			{
				retval:= "Loop"
			}
			; search for a thread variable with that name
			else if (_existsThreadProperty(Environment.InstanceID, Environment.ThreadID, "threadvarsHidden." p_Name))
			{
				retval:= "Thread"
			}
		}
		; search for an intance variable with that name
		else if (_existsInstanceProperty(Environment.InstanceID, "InstanceVarsHidden." p_Name))
		{
			retval := "instance"
		}
	}

	_LeaveCriticalSection()
	return retval
}

; set a variable
; p_Destination: if empty, the location of that variable will be derived from its name and can only be "instance", "global" or "static". Variable name mustn't start with "A_"
;   p_Destination can be "thread" or "loop", then the variable name must start with "A_"
Var_Set(Environment, p_Name, p_Value, p_Destination="", p_hidden = False)
{
	if (isobject(p_Name))
	{
		throw exception("p_Name is an object")
	}
	
	; check variable name
	res := Var_CheckName(p_Name, true)
	if (res = "empty")
	{
		logger("f0", "Setting a variable failed. Its name is empty.", Environment.FlowID)
		return
	}
	else if (res = "ForbiddenCharacter")
	{
		logger("f0", "Setting variable '" p_Name "' failed. It contains forbidden characters.", Environment.FlowID)
		return
	}
	; else variable name is valid

	; get the destination of the variable (and also check whether it is allowed to set it)
	destination := Var_RetrieveDestination(p_Name, p_Destination)

	if (destination and not instr(destination, "error_"))
	{
		; it is allowed to set the variable and we can set it
		if not (isfunc(destination "Variable_Set"))
		{
			throw exception("function ''" destination "Variable_Set' does not exist")
		}
		%destination%Variable_Set(environment, p_Name, p_Value, p_hidden)
	}
	else
	{
		; there was an error or destination is 
		if (destination = "error_noPermission")
		{
			logger("f0","Setting variable '" p_Name "' failed. No permission.", Environment.FlowID)
		}
		else if (destination = "error_NotStartWith_A")
		{
			logger("f0","Setting variable '" p_Name "' failed. It does not start with 'A_'.", Environment.FlowID)
		}
		else
		{
			throw exception("destination variable returned by Var_RetrieveDestination() is empty")
		}
	}
}

; get value of a variable
Var_Get(environment, p_Name, p_hidden = False)
{
	if (isobject(p_Name))
	{
		throw exception("p_Name is an object", -1)
	}

	; get the location of the variable and check whether it exists
	varLocation := Var_GetLocation(Environment, p_Name, p_hidden)
	if (varLocation)
	{
		; variable exists. Get the value
		if not (isfunc(varLocation "Variable_Get"))
		{
			throw exception("function ''" varLocation "Variable_Get' does not exist")
		}

		logger("f3","Retrieving " varLocation " variable '" p_Name "'", Environment.FlowID)
		varValue := %varLocation%Variable_Get(environment, p_Name, p_hidden)
		return varValue
	}
	else
	{
		logger("f0","Retrieving variable '" p_Name "' failed. It does not exist", Environment.FlowID)
	}
}

; get type of a variable. If variable exists, it returns "object" or "normal": If variable does not exist or is empty, it returns nothing.
Var_GetType(Environment, p_Name, p_hidden = False)
{
	; first find the location of variable (and so check whether it exist)
	varLocation := Var_GetLocation(Environment, p_Name, p_hidden)
	if (varLocation)
	{
		; variable exists

		if not (isfunc(varLocation "Variable_Get"))
		{
			throw exception("function ''" varLocation "Variable_Get' does not exist")
		}

		; get variable value
		variable := %varLocation%Variable_Get(Environment, p_Name, p_hidden)

		; check the type of variable
		if IsObject(variable)
		{
			return "object"
		}
		else
		{
			return "normal"
		}
	}
	; else return nothing if variable does not exist
}

; delete a variable
Var_Delete(Environment, p_Name, p_hidden = False)
{
	; first find the location of variable (and so check whether it exist)
	varLocation := Var_GetLocation(Environment, p_Name, p_hidden)
	if (varLocation)
	{
		; variable exists

		if not (isfunc(varLocation "Variable_Get"))
		{
			throw exception("function ''" varLocation "Variable_Get' does not exist")
		}

		; delete variable
		%varLocation%Variable_Delete(Environment, p_Name, p_hidden)
	}
}

; replace variables inside a string which are encased with percent signs
; pars: if it contains "ConvertObjectToString": if value of variable is an object, it will be converted to string
Var_replaceVariables(environment, p_String, pars = "")
{
	; copy string
	tempstring := p_String

	; start endless loop where we replace all occurrences
	Loop
	{
		; find first variable name in the string which is encased in percent signs. Write found variable name
		tempFoundPos := RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)

		; break, if we didn't find a string
		if (tempFoundPos = 0)
			break
		
		; get the value of the variable
		tempVarValue := Var_Get(environment, tempFoundVarName1)
		
		; if value is an object
		if isobject(tempVarValue)
		{
			; if requested, convert the value to string
			IfInString, pars, ConvertObjectToString
				tempVarValue := Jxon_Dump(tempVarValue, 2,, true) ; do not convert unicode chars
		}
		
		; replace the found variable in string
		StringReplace, tempstring, tempstring, `%%tempFoundVarName1%`%, % tempVarValue
	}
	
	return tempstring
}
