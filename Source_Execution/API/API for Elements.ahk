
;This file provides functions which can be accessed by the code inside the elements.

x_RegisterElementClass(p_class)
{
	xx_RegisterElementClass(p_class)
}

;Variable API functions: different in execution
; get a variable
x_GetVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Get(Environment, p_Varname, p_hidden )
}
; get a variable type
x_getVariableType(Environment, p_Varname, p_hidden = False)
{
	return Var_GetType(Environment, p_Varname, p_hidden )
}
; set a variable
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	return Var_Set(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
; delete a variable
x_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Delete(Environment, p_Varname, p_hidden)
}
; Get a variable location
x_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	return Var_GetLocation(Environment, p_Varname, p_hidden)
}

; Replace variables which are encased by percent signs
x_replaceVariables(Environment, p_String, p_pars ="")
{
	return Var_replaceVariables(Environment, p_String, p_pars)
}
; evaluate an expression
x_EvaluateExpression(Environment, p_String)
{
	return Var_EvaluateExpression(Environment, p_String, false)
}
; execute an AHF scriopt
x_EvaluateScript(Environment, p_script)
{
	var_evaluateScript(Environment, p_script, false)
}

; checks a variable name, whether it is valid
x_CheckVariableName(p_VarName)
{
	return Var_CheckName(p_VarName)
}

; evaluate all parameters of an element
; p_skipList: parameters which won't be evaluated
x_AutoEvaluateParameters(Environment, ElementParameters, p_skipList = "")
{
	_EnterCriticalSection()

	; get element parametration details
	elementClass := _getElementProperty(Environment.FlowID, Environment.ElementID, "class")
	ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)

	; prepare variable with the evaluated parameters which will be returned
	EvaluatedParameters:=Object()
	
	; loop through all parameters
	for oneParIndex, onePar in ParametrationDetails
	{
		if (not onePar.id)
		{
			; this element in parametration details has not parameter which could be evaluated
			continue
		}
		; sometimes, parameter ID is a string, sometimes an array of strings. Convert it to array if it is a string
		if (not isObject(onePar.id))
			parIDs:=[onePar.id]
		else
			parIDs:=onePar.id
		
		; loop through all paramter IDs
		for oneIndex, oneParID in parIDs
		{
			;Label and button cannot be evaluated
			if (onePar.type = "label" or onPar.type = "Button")
			{
				continue
			}
			
			;skip parameter if it is in the passed skip list
			if (ObjHasValue(p_skipList, oneParID))
				continue
			
			; evaluate the parameter
			x_AutoEvaluateOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
			if (EvaluatedParameters._error)
			{
				;Stop evaluating if an error occurs
				break
			}
		}
	}
	
	_LeaveCriticalSection()
	return EvaluatedParameters
}

; additionally evaluate some parameters of an element
; EvaluatedParameters: already evaluated parameters (can be empty)
; p_ParametersToEvaluate: Array of parameter names which need to be evaluated
x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
	_EnterCriticalSection()

	; create return object if it is not an object yet
	if not isobject(EvaluatedParameters)
		EvaluatedParameters:=Object()
	
	; get element parametration details
	elementClass := _getElementProperty(Environment.FlowID, Environment.ElementID, "class")
	ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
	
	; loop through all parameters
	for oneParIndex, onePar in ParametrationDetails
	{
		if (not onePar.id)
		{
			; this element in parametration details has not parameter which could be evaluated
			continue
		}
		; sometimes, parameter ID is a string, sometimes an array of strings. Convert it to array if it is a string
		if (not isObject(onePar.id))
			parIDs:=[onePar.id]
		else
			parIDs:=onePar.id
		
		for oneIndex, oneParID in parIDs
		{
			;Label and button cannot be evaluated
			if (onePar.type = "label" or onPar.type = "Button")
			{
				continue
			}

			; check whether the parameter needs to be evaluated
			for onePartoEvalIndex, onePartoEval in p_ParametersToEvaluate
			{
				if (onePartoEval = oneParID)
				{
					; evaluate the parameter
					x_AutoEvaluateOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
					break
				}
			}

			;Stop evaluating if an error occurs
			if (EvaluatedParameters._error)
				break
		}
	}
	_LeaveCriticalSection()
}

; evaluate a single parameter, depending on its type
; oneParID: the ID of the paraemter which needs to be evaluated
; onePar: whole element from the call of Element_getParametrizationDetails(). Should be set, if available. Otherways Element_getParametrizationDetails() will be called
x_AutoEvaluateOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
	_EnterCriticalSection()
	if not (onePar)
	{
		; onePar is not set, we need to call Element_getParametrizationDetails() again
		elementClass := _getElementProperty(Environment.FlowID, Environment.ElementID, "class")
		ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)

	;	 loop through all parameters
		for oneParIndex, oneParDetails in ParametrationDetails
		{
			if (not oneParDetails.id)
			{
				; this element in parametration details has not parameter which could be evaluated
				continue
			}
			; sometimes, parameter ID is a string, sometimes an array of strings. Convert it to array if it is a string
			if (not isObject(oneParDetails.id))
				parIDs:=[oneParDetails.id]
			else
				parIDs:=oneParDetails.id
			
			; if the parameter is in this list, take it 
			if (ObjHasValue(parIDs, oneParID))
			{
				onePar := oneParDetails
				break
			}
		}
	}
	
	; sometimes, the content type has one value (like "string", "expression", etc.)
	; but it can also be changeable by the user. In this case, onePar.content contains an array
	if (IsObject(onePar.content))
	{
		; content type is changeable by user. The selected content type is in the paramter with name in onePar.contentID.
		oneParContent := ElementParameters[onePar.contentID]
	}
	else
	{
		; content type is not changeable by user.
		oneParContent := onePar.content
	}
	
	if (onePar.type = "file" or onepar.type = "folder")
	{
		; parameter type is a file or folder.
		; the content type is always "string"
		; Replace variables encased by percent signs in string (if any)
		result := x_replaceVariables(Environment, ElementParameters[oneParID])
		if (onePar.WarnIfEmpty)
		{
			; if parameter must be set and is empty, add a warning
			if (result = "")
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("String '%1%' is empty", ElementParameters[oneParID])
			}
		}

		; if path is relative, convert it to full path
		EvaluatedParameters[oneParID] := x_GetFullPath(Environment, result)
	}
	else
	{
		; parameter type is anything else than file or folder
		; the content type may be set
		if (oneParContent = "string")
		{
			; content type is "string". Replace variables encased by percent signs in string (if any)
			result := x_replaceVariables(Environment,ElementParameters[oneParID])
			if (onePar.WarnIfEmpty)
			{
				; if parameter must be set and is empty, add a warning
				if (result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("String '%1%' is empty", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID] := result
		}
		else if (oneParContent = "expression" or oneParContent = "number")
		{
			; content type is "expression" or "number". We will evaluate the expression
			evRes := x_evaluateExpression(Environment,ElementParameters[oneParID])
			if (evRes.error)
			{
				; if there was an error during evaluation of the expression, add a warning
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("An error occured while parsing expression '%1%'", ElementParameters[oneParID]) "`n`n" evRes.error
			}
			if (onePar.WarnIfEmpty)
			{
				; if parameter must be set and is empty, add a warning
				if (evRes.result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Result of expression '%1%' is empty", ElementParameters[oneParID])
				}
			}
			if (oneParContent = "number")
			{
				; if parameter type is "number", check whether the value is a number
				temp := evRes.result
				if temp is not number
				{
					; the value is not a number, add a warning
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Result of expression '%1%' is not a number", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID] := evRes.result
		}
		else if (oneParContent = "VariableName")
		{
			; content type is "VariableName". Replace variables encased by percent signs in string (if any) to allow 
			result := x_replaceVariables(Environment, ElementParameters[oneParID])
			; check the variable name, whether it is a valid name and is not empty
			if not x_CheckVariableName(result)
			{
				; variable is invalid. add a warning
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("%1% is not valid", lang("Variable name '%1%'", result))
			}
			EvaluatedParameters[oneParID] := result
		}
		else if (oneParContent = "RawString" or not oneParContent)
		{
			; the parameter type is "rawString" or not set. We won't change the value
			result := ElementParameters[oneParID]
			if (onePar.WarnIfEmpty)
			{
				; if parameter must be set and is empty, add a warning
				if (result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Parameter '%1%' is empty", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID] := result
		}
		else
		{
			; content type has an uknown value. add a warning
			EvaluatedParameters._error := true
			EvaluatedParameters._errorMessage := lang("Parameter '%1%' has unsupported content type", ElementParameters[oneParID])
		}
	}
	_LeaveCriticalSection()
	return EvaluatedParameters
}

; get list of all variable names
x_GetListOfAllVars(Environment)
{
	return Var_GetListOfAllVars(Environment)
}
; get list of all loop variable names
x_GetListOfLoopVars(Environment)
{
	return Var_GetListOfLoopVars(Environment)
}
; get list of all thread variable names
x_GetListOfThreadVars(Environment)
{
	return Var_GetListOfThreadVars(Environment)
}
; get list of all instance variable names
x_GetListOfInstanceVars(Environment)
{
	return Var_GetListOfInstanceVars(Environment)
}
; get list of all static variable names
x_GetListOfStaticVars(Environment)
{
	return Var_GetListOfStaticVars(Environment)
}
; get list of all global variable names
x_GetListOfGlobalVars(Environment)
{
	return Var_GetListOfGlobalVars(Environment)
}

; get an object with all instance variables (with values)
x_ExportAllInstanceVars(Environment)
{
	return _getInstanceProperty(Environment.InstanceID, "InstanceVars")
}
; sets all varaibles which are passed in p_VarsToImport as instance variables
x_ImportInstanceVars(Environment, p_VarsToImport)
{
	for onevarName, oneVar in p_VarsToImport
	{
		InstanceVariable_Set(Environment, onevarName, oneVar)
	}
}

; finishes execution of an element.
; After that, the next elements which are connected to the current element will be executed.
x_finish(Environment, p_Result, p_Message = "")
{
	finishExecutionOfElement(Environment.InstanceID, Environment.ThreadID, p_Result, p_Message)
}

; gets the entry point of an element which has more than one entry point.
; It is used with loops and returns "head" or "tail". If called in other element types, it will return an empty value.
x_getEntryPoint(Environment)
{
	return _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "ElementEntryPoint")
}

; stop the current instance
x_InstanceStop(Environment)
{
	stopInstance(Environment.instanceID)
}

; Returns a string which is unique during the execution of the current element. Usercases:
; - Use as GUI name.
; - get the environment variable if only this unique execution ID is known with x_GetMyEnvironmentFromExecutionID()
x_GetMyUniqueExecutionID(Environment)
{
	return _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "UniqueID")
}

; returns the environment variable using the unique execution ID, which can be retrieved with x_GetMyUniqueExecutionID()
x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
	return global_AllExecutionIDs[p_ExecutionID].environment
}

; set a variable which will be available during the execution of the element
x_SetExecutionValue(Environment, p_name, p_Value)
{
	_EnterCriticalSection()
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "ElementExecutionValues." p_name, p_value, false)
	_LeaveCriticalSection()
}
; get a variable which is available during the execution of the element
x_GetExecutionValue(Environment, p_name)
{
	_EnterCriticalSection()
	retval := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "ElementExecutionValues." p_name, false)
	_LeaveCriticalSection()
	return retval
}

; returns a function object which calls a defined function with the defined parameters.
; the returned function object itself has no parameters and thus can be used as a callback function for times etc.
; it is used to route a callback (which has no parameters) to a function with parameters.
; the first parameter of the called function will always contain the environment variable.
; if the function object will be called with parameters, they will appear after the environment parameter, after them the params* will be passed.
; Usecases:
; - settimer callbacks, which will be routed to the desired function
; - callback of an external AHK thread (use with x_ExecuteInNewAHKThread())
x_NewExecutionFunctionObject(Environment, p_ToCallFunction, params*)
{
	_EnterCriticalSection()
	; create a new function object
	oneFunctionObject := new Class_FunctionObject(Environment, p_ToCallFunction, params*)

	; set the unique ID and write it to a global variable
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")
	global_AllExecutionIDs[uniqueID].ExecutionFunctionObjects[p_ToCallFunction] = oneFunctionObject

	_LeaveCriticalSection()
	return oneFunctionObject
}


; Function object for function x_NewExecutionFunctionObject
class Class_FunctionObject
{
    __New(Environment, ToCallFunction, params*) 
	{
		; save information which we will need if the function object will be called
        this.Environment := Environment
		this.ToCallFunction := ToCallFunction
		this.params := params

		; create and return the function object
        this.FunctionObject := ObjBindMethod(this, Call)
		return this.FunctionObject
    }

	; function which will be called when the function object will be called
    Call(args*) 
	{
		; tha argument "args*" may contain parameters which were passed to the called funtion object
		; if the function did not get any parameters, create a new object
		if not isobject(args)
			args := Object()

		; Add parameters which were passed to as "params*" when the function object was created (if any)
		for oneparindex, onepar in this.params
		{
			args.push(onepar)
		}

		; get the function name
		ToCallFunction := this.ToCallFunction
		
		; call the function with the environment as first argument and the additional arguments (if any)
		%ToCallFunction%(this.Environment, args*)
    }
	
	; general pattern as documented in https://www.autohotkey.com/docs/objects/Functor.htm
	__Call(method, args*) {
        if (method = "")  ; For %fn%() or fn.()
            return this.Call(args*)
        if (IsObject(method))  ; If this function object is being used as a method.
            return this.Call(method, args*)
    }
	
	; todo: delete functions object if execution of an element finished
	__delete()
	{
		MsgBox Class_FunctionObject __delete
	}
}

; Returns the count of threads in current execution instance
; todo: refactor if used
x_GetThreadCountInCurrentInstance(Environment)
{
	_EnterCriticalSection()

	allThreadIDs := _getAllThreadIds(Environment.InstanceID)
	count := 0
	for oneinstanceIndex, oneInstanceID in allThreadIDs
	{
		if (oneInstanceID = Environment.InstanceID)
		{
			count++
		}
	}
	_LeaveCriticalSection()
	return count
}


; execute some code in a new ahk thread
; p_functionObject: function which will be called when the execution finishes
; p_Code: source code which will be executed
; p_VarsToImport: variables which will be set before the code will be executed
; p_VarsToExport: variables which will be retrieved after the code ends and then passed to the function object
; more to consider in the passed code:
; - do not use variables and labels which start with "ahf_"
; - do not use following calls and functions: onexit, EnterCriticalSection(), LeaveCriticalSection()
; - the script is always persistent. But if the code reaches the end, it will always exit. Add a return on the end of the script to prevent that.
; - do not use a_workingdir and do not change working directory
x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	_EnterCriticalSection()

	; get unique ID of the element
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")

	; write some information in the global variable
	if not isobject(global_AllExecutionIDs[uniqueID])
		global_AllExecutionIDs[uniqueID] := object()
	global_AllExecutionIDs[uniqueID].ExeInNewThread := object()
	global_AllExecutionIDs[uniqueID].ExeInNewThread.functionObject := p_functionObject
	
	; create a shared object which will be shared with the new ahk thread
	sharedObject := CriticalObject()
	sharedObject.varsToImport := p_VarsToImport
	sharedObject.varsToExport := p_VarsToExport
	sharedObject.varsExported := Object()
	_setSharedProperty("temp." uniqueID, {sharedObject: sharedObject}, false)
	
	; define some code which will be appended before p_Code
	; make code persistent
	preCode := ""
	preCode .= "#persistent`n"
	preCode .= "#NoTrayIcon`n"
	; on exit, go to the exit routine
	preCode .= "onexit, ahf_onexit`n"
	; we will need the unique ID for the callback function
	preCode .= "ahf_uniqueID :=""" uniqueID """`n"
	; get the critical section
	preCode .= "ahf_cs_shared := " _cs_shared "`n"
	; get the shared object
	preCode .= "ahf_sharedObject := CriticalObject(" (&sharedObject) ")`n"
	; We will need the parent thread (the execution thread) in order to directly call a function there
	preCode .= "ahf_parentAHKThread := AhkExported()`n"
	; set all variables from p_VarsToImport. since we access a shared variable, use critical section
	preCode .= "EnterCriticalSection(ahf_cs_shared)`n"
	preCode .= "for ahf_varname, ahf_varvalue in ahf_sharedObject.varsToImport`n"
	preCode .= "{`n"
	preCode .= "  %ahf_varname%:=ahf_VarValue`n"
	preCode .= "}`n"
	preCode .= "LeaveCriticalSection(ahf_cs_shared)`n"

	; define some code which will be appended after p_Code
	postcode := ""
	; always exit app if p_Code reaches the end
	postcode .= "exitapp`n"
	; label which will be executed on call of exitapp
	postcode .= "ahf_onexit:`n"
	
	; set all variables from p_VarsToExport. since we access a shared variable, use critical section
	postcode .= "EnterCriticalSection(ahf_cs_shared)`n"
	postcode .= "for ahf_varindex, ahf_varname in ahf_sharedObject.varsToExport`n{`n  ahf_sharedObject.varsExported[ahf_varname] := %ahf_varname%`n}`n"
	postcode .= "LeaveCriticalSection(ahf_cs_shared)`n"
	; call a function from parent thread to notify it that it has finished
	postcode .= "ahf_parentAHKThread.ahkFunction(""API_Main_ElementThread_Stopped"", ahf_uniqueID)`n"
	; finally exit the thread
	postcode .= "exitapp"
	_LeaveCriticalSection()
	
	; finally start the new ahk thread
	API_Main_StartElementAhkThread(uniqueID, "`n" preCode "`n" p_Code "`n" postCode)
}

; stops the ahk thread of a element which used x_ExecuteInNewAHKThread() when it was started
; todo: implement a more clean exit where the thread gets a signal and then stops itself
x_ExecuteInNewAHKThread_Stop(Environment)
{
	; get the unique ID
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")

	; tell the main thread to stop the element ahk thread
	API_Main_StopElementAhkThread(uniqueID)
}

; is called when the code which was executing a new ahk-thread using x_ExecuteInNewAHKThread() finishes
ExecuteInNewAHKThread_finishedExecution(p_ExecutionID)
{
	_EnterCriticalSection()
	; get the environment variable
	Environment := x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
	; get the function object
	functionObject := global_AllExecutionIDs[p_ExecutionID].ExeInNewThread.functionObject
	; get the exported variables
	varsExported := _getSharedProperty("temp." p_ExecutionID ".sharedObject.varsExported")
	_LeaveCriticalSection()

	; call the function object and pass the exported variables
	%functionObject%(varsExported)
}

;exeuction of a trigger in other ahk thread
x_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
	_EnterCriticalSection()

	; get unique ID of the element
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")

	; write some information in the global variable
	if not isobject(global_AllActiveTriggerIDs[uniqueID])
		global_AllActiveTriggerIDs[uniqueID]:=object()
	global_AllActiveTriggerIDs[uniqueID].ExeInNewThread:=object()
	global_AllActiveTriggerIDs[uniqueID].environment:=Environment
	
	; create a shared object which will be shared with the new ahk thread
	sharedObject:=CriticalObject()
	sharedObject.varsToImport:=p_VarsToImport
	sharedObject.varsToExport:=p_VarsToExport
	sharedObject.varsExported:=Object()
	_setSharedProperty("temp." uniqueID, {sharedObject: sharedObject}, false)
	
	; define some code which will be appended before p_Code
	; make code persistent
	preCode := ""
	preCode .= "#persistent`n"
	preCode .= "#NoTrayIcon`n"
	; we will need the unique ID for the callback function
	preCode .= "ahf_uniqueID :=""" uniqueID """`n"
	; get the critical section
	preCode .= "ahf_cs_shared := " _cs_shared "`n"
	; get the shared object
	preCode .= "ahf_sharedObject := CriticalObject(" (&sharedObject) ")`n"
	; We will need the parent thread (the execution thread) in order to directly call a function there
	preCode .= "ahf_parentAHKThread := AhkExported()`n"
	; set all variables from p_VarsToImport. since we access a shared variable, use critical section
	preCode .= "EnterCriticalSection(ahf_cs_shared)`n"
	preCode .= "for ahf_varname, ahf_varvalue in ahf_sharedObject.varsToImport`n"
	preCode .= "{`n"
	preCode .= "  %ahf_varname%:=ahf_VarValue`n"
	preCode .= "}`n"
	preCode .= "LeaveCriticalSection(ahf_cs_shared)`n"
	
	; define some code which will be appended after p_Code
	postcode := ""
	; return if code reaches the end
	postcode .= "return`n"
	; define function which needs to be called in order to trigger the trigger
	postcode .= "x_trigger()`n"
	postcode .= "{`n"
	postcode .= "global`n"
	; set all variables from p_VarsToExport. since we access a shared variable, use critical section
	postcode .= "EnterCriticalSection(ahf_cs_shared)`n"
	postcode .= "for ahf_varindex, ahf_varname in ahf_sharedObject.varsToExport`n{`n  ahf_sharedObject.varsExported[ahf_varname]:=%ahf_varname%`n}`n"
	postcode .= "LeaveCriticalSection(ahf_cs_shared)`n"
	; call a function from parent thread to notify it that it has finished
	postcode .= "ahf_parentAHKThread.ahkFunction(""API_Main_ElementThread_Trigger"", ahf_uniqueID)`n"
	postcode .= "}`n"
		
	_LeaveCriticalSection()

	; start the new ahk thread
	API_Main_StartElementAhkThread(uniqueID, "`n" preCode "`n" p_Code "`n" postCode)

	; remember the thread ID in order to be able to stop the external thread when the trigger is disabled
	global_AllActiveTriggerIDs[uniqueID].ExeInNewThread.AHKThread := AHKThread
}

; stops the ahk thread of a trigger which used x_TriggerInNewAHKThread() when it was enabled
; todo: implement a more clean exit where the thread gets a signal and then stops itself
x_TriggerInNewAHKThread_Stop(Environment)
{
	_EnterCriticalSection()
	; get the unique ID
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")

	; tell the main thread to stop the element ahk thread
	API_Main_StopElementAhkThread(uniqueID)
}

; called when a trigger which is running in an separate ahk-thread triggers
ExecuteInNewAHKThread_trigger(p_uniqueID)
{
	_EnterCriticalSection()
	; get the environment variable.
	Environment := global_AllActiveTriggerIDs[p_uniqueID].environment
	; get the variables which the trigger has passed.
	; TODO: Does it work, if trigger tirggers multiple times at once?
	varsExportedFromExternalThread := _getSharedProperty("temp." p_uniqueID ".sharedObject.varsExported")
	; TODO: what?? does the enviroment variable contain einstance and thread ID? 
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "varsExportedFromExternalThread", varsExportedFromExternalThread)

	_LeaveCriticalSection()

	; trigger the trigger
	x_trigger(Environment)
}

; TODO: Does it work, if trigger tirggers multiple times at once?
x_TriggerInNewAHKThread_GetExportedValues(Environment)
{
	_EnterCriticalSection()
	retval := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "varsExportedFromExternalThread")
	_LeaveCriticalSection()
	return retval
}





; only in nexecution
; trigger a trigger and create a new instance
x_trigger(Environment)
{
	newInstance(Environment)
}

; must be called when the trigger was enabled.
; Result: must contain "normal" or "expection"
; Message: if Result is "exception", Message must contain the error message which will be shown to the user 
x_enabled(Environment, Result, Message = "")
{
	saveResultOfTriggerEnabling(Environment, Result, Message)
}

; must be called when the trigger was disabled.
; Result: must contain "normal" or "expection"
; Message: if Result is "exception", Message must contain the error message which will be shown to the user 
x_disabled(Environment, Result, Message = "")
{
	saveResultOfTriggerDisabling(Environment, Result, Message)
}



x_GetMyFlowID(Environment)
{
	return xx_GetMyFlowID(Environment)
}
x_GetMyFlowName(Environment)
{
	return xx_GetMyFlowName(Environment)
}

x_GetMyElementID(Environment)
{
	return xx_GetMyElementID(Environment)
}

x_getFlowIDByName(p_FlowName)
{
	return xx_getFlowIDByName(p_FlowName)
}



x_FlowExistsByName(p_FlowName)
{
	return xx_FlowExistsByName(p_FlowName)
}

x_FlowExists(p_FlowID)
{
	return xx_FlowExists(p_FlowID)
}


x_isFlowEnabled(p_FlowID)
{
	return xx_isFlowEnabled(p_FlowID)
}



x_isFlowExecuting(p_FlowID)
{
	return xx_isFlowExecuting(p_FlowID)
}


x_FlowEnable(p_FlowID)
{
	return xx_FlowEnable(p_FlowID)

}


x_FlowDisable(p_FlowID)
{
	return xx_FlowDisable(p_FlowID)
	
}

x_FlowStop(p_FlowID)
{
	return xx_FlowStop(p_FlowID)
}


x_GetListOfFlowNames()
{
	return xx_GetListOfFlowNames()
}

x_GetListOfFlowIDs()
{
	return xx_GetListOfFlowIDs()
}


x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	return xx_getAllElementIDsOfType(p_FlowID, p_Type)
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	return xx_getAllElementIDsOfClass(p_FlowID, p_Class)
}

x_getElementPars(p_FlowID, p_ElementID)
{
	return xx_getElementPars(p_FlowID, p_ElementID)
}
x_getElementName(p_FlowID, p_ElementID)
{
	return xx_getElementName(p_FlowID, p_ElementID)
}
x_getElementClass(p_FlowID, p_ElementID)
{
	return xx_getElementClass(p_FlowID, p_ElementID)
}

x_getMyElementPars(Environment)
{
	return xx_getMyElementPars(Environment)
}


x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	return xx_ManualTriggerExist(p_FlowID, p_TriggerName)
}

x_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	return xx_isManualTriggerEnabled(p_FlowID, p_TriggerName)
}

x_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	return xx_ManualTriggerEnable(p_FlowID, p_TriggerName)
}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	return xx_ManualTriggerDisable(p_FlowID, p_TriggerName)
}

x_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
	return xx_ManualTriggerExecute(p_FlowID, p_TriggerName, p_Variables, p_CallBackFunction)
}


x_Par_Disable(p_ParameterID, p_TrueOrFalse = True)
{
	return xx_Par_Disable(p_ParameterID, p_TrueOrFalse)
}
x_Par_Enable(p_ParameterID, p_TrueOrFalse = True)
{
	return xx_Par_Enable(p_ParameterID, p_TrueOrFalse)
}
x_Par_SetValue(p_ParameterID, p_Value)
{
	return xx_Par_SetValue(p_ParameterID, p_Value)
}
x_Par_GetValue(p_ParameterID)
{
	return xx_Par_GetValue(p_ParameterID)
}
x_Par_SetChoices(p_ParameterID, p_Choices)
{
	return xx_Par_SetChoices(p_ParameterID, p_Choices)
}
x_Par_SetLabel(p_ParameterID, p_Label)
{
	return xx_Par_SetLabel(p_ParameterID, p_Label)
}
x_FirstCallOfCheckSettings(Environment)
{
	return xx_FirstCallOfCheckSettings(Environment)
}

x_randomPhrase()
{
	return xx_randomPhrase()
}
x_ConvertObjToString(p_Value)
{
	return xx_ConvertObjToString(p_Value)
}
x_ConvertStringToObj(p_Value)
{
	return xx_ConvertStringToObj(p_Value)
}



x_log(Environment, LoggingText, loglevel = 2)
{
	return xx_log(Environment, LoggingText, loglevel)
}

x_GetFullPath(Environment, p_Path)
{
	return xx_GetFullPath(Environment, p_Path)
}

x_GetWorkingDir(Environment)
{
	return xx_GetWorkingDir(Environment)
}


x_assistant_windowParameter(neededInfo)
{
	return xx_assistant_windowParameter(neededInfo)
}

x_assistant_MouseTracker(neededInfo)
{
	return xx_assistant_MouseTracker(neededInfo)
}

x_assistant_ChooseColor(neededInfo)
{
	return xx_assistant_ChooseColor(neededInfo)
}

x_GetAhfPath()
{
	return xx_GetAhfPath()
}

; only in execution
;Returns whether AHF was just started with Windows. Can only be used by triggers.
x_isWindowsStartup()
{
	return _getShared("WindowsStartup")
}