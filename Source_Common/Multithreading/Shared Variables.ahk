;This module contains the access function for all shared data between the ahk-Threads
;There are a few other functions which can access the shared data, too:
;x_TriggerInNewAHKThread
;x_ExecuteInNewAHKThread

criticalSectionCounter := 0

	
; exit routine inside _EnterCriticalSection:
; when the application closes, the main thread informs all threads that they must stop
; We have to make sure, that the threads close, while not blocking the critical section (excluding main thread).
; to do so, each thread keeps track whether it blocks the critical section (with variable criticalSectionCounter)
; Whenever the is going to block the critical section, it checks whether it has to stop.
; If so, the thread sends a message to main thread that it can now be killed and at same time stops the pseudo ahk thread
_EnterCriticalSection()
{
	global criticalSectionCounter
	global API_Main_Thread_Stopped_sent
	
	; if below exit code already executed, do not enter critical section
	if API_Main_Thread_Stopped_sent
	{
		exit  ; stop the pseudo-ahk-thread
	}
	Critical on
	EnterCriticalSection(_cs_shared)
	if (criticalSectionCounter == 0 and (_share.exiting or _exiting) and not _ahkThreadID="Main")
	{
		; send the message to main only once
		if not API_Main_Thread_Stopped_sent
		{
			API_Main_Thread_Stopped_sent := true
			API_Main_Thread_Stopped(_ahkThreadID)
		}

		; Leave critical section 
		LeaveCriticalSection(_cs_shared)
		onexit, FinallyExit
		exitapp ; stop the pseudo-ahk-thread
	}

	criticalSectionCounter++
}

_LeaveCriticalSection()
{
	global criticalSectionCounter
	criticalSectionCounter--
	
	LeaveCriticalSection(_cs_shared)
	if (criticalSectionCounter = 0)
		Critical off
}

_isExiting()
{
	EnterCriticalSection(_cs_shared)
	exiting := _share.exiting
	LeaveCriticalSection(_cs_shared)
	return exiting
}

_setShared(path, value)
{
	_EnterCriticalSection()
    _share[path] := ObjFullyClone(value)
	_LeaveCriticalSection()
}
_getShared(path)
{
	_EnterCriticalSection()
    value:=ObjFullyClone(_share[path])
	_LeaveCriticalSection()
    return value
}
_getSharedProperty(path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_share, path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	_LeaveCriticalSection()
    return value
}
_setSharedProperty(path, value, clone = true)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_share, path)
	if (clone)
	{
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	}
	Else
	{
    	objectPath[1][objectPath[2]] := value
	}
	_LeaveCriticalSection()
}
_getAndIncrementShared(path, incrementValue = 1)
{
	_EnterCriticalSection()
    _share[path] += incrementValue
    value:=_share[path]
	_LeaveCriticalSection()
    return value
}
_appendToShared(path, appendValue)
{
	_EnterCriticalSection()
    _share[path] .= appendValue
	_LeaveCriticalSection()
}
_getAllSharedKeys()
{
	_EnterCriticalSection()
    allKeys:=[]
    for forKey, forValue in _share
	{
		allKeys.push(forKey)
	}
	_LeaveCriticalSection()
    return allKeys
}


_setSettings(path, value)
{
	_EnterCriticalSection()
    _settings[path] := ObjFullyClone(value)
	_LeaveCriticalSection()
}
_getSettings(path)
{
	_EnterCriticalSection()
    value:=ObjFullyClone(_settings[path])
	_LeaveCriticalSection()
    return value
}
_setTask(path, value)
{
	_EnterCriticalSection()
    _share[path].Tasks.push(value)
	_LeaveCriticalSection()
}
_getTask(path)
{
	_EnterCriticalSection()
    value:=_share[path].Tasks.removeat(1)
	_LeaveCriticalSection()
    return value
}


_getFlow(FlowID)
{
	_EnterCriticalSection()
    flow:=ObjFullyClone(_flows[FlowID])
	_LeaveCriticalSection()
    return flow
}
_setFlow(FlowID, flow)
{
	_EnterCriticalSection()
    _flows[FlowID] := ObjFullyClone(flow)
	_LeaveCriticalSection()
}
_deleteFlow(FlowID)
{
	_EnterCriticalSection()
    _flows.delete(FlowID)
	_LeaveCriticalSection()
}
_getFlowProperty(FlowID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	_LeaveCriticalSection()
    return value
}
_setFlowProperty(FlowID, path, value, clone = true)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID], path)
	if (clone)
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
		objectPath[1][objectPath[2]] := value
	_LeaveCriticalSection()
}
_deleteFlowProperty(FlowID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID], path)
    objectPath[1].delete(objectPath[2])
	_LeaveCriticalSection()
    return value
}
_getAndIncrementFlowProperty(FlowID, path)
{
	_EnterCriticalSection()
    value:=++_flows[FlowID][path]
	_LeaveCriticalSection()
    return value
}
_existsFlow(FlowID)
{
	_EnterCriticalSection()
    result := _flows.haskey(FlowID)
	_LeaveCriticalSection()
    return result
}
_getFlowIdByName(FlowName)
{
	_EnterCriticalSection()
    for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = FlowName)
		{
			retval:= forFlowID
            break
		}
	}
	_LeaveCriticalSection()
    return retval
}
_getAllFlowIds()
{
	_EnterCriticalSection()
    allFlows:=[]
    for forFlowID, forFlow in _Flows
	{
		allFlows.push(forFlowID)
	}
	_LeaveCriticalSection()
    return allFlows
}
_getAllFlowPropertyKeys(FlowID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID], path)
    allKeys:=[]
    for forKey, forValue in objectPath[1][objectPath[2]]
	{
		allKeys.push(forKey)
	}
	_LeaveCriticalSection()
    return allKeys
}

_getCategory(CategoryId)
{
	_EnterCriticalSection()
    category:=ObjFullyClone(_share.allCategories[CategoryId])
	_LeaveCriticalSection()
    return category
}
_setCategory(CategoryId, newCategory)
{
	_EnterCriticalSection()
    _share.allCategories[CategoryId] := ObjFullyClone(newCategory)
	_LeaveCriticalSection()
}
_deleteCategory(CategoryId)
{
	_EnterCriticalSection()
    _share.allCategories.delete(CategoryId)
	_LeaveCriticalSection()
}
_getCategoryProperty(CategoryId, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_share.allCategories[CategoryId], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	_LeaveCriticalSection()
    return value
}
_setCategoryProperty(CategoryId, path, value)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_share.allCategories[CategoryId], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	_LeaveCriticalSection()
}
_existsCategory(CategoryId)
{
	_EnterCriticalSection()
    result := _share.allCategories.haskey(CategoryId)
	_LeaveCriticalSection()
    return result
}
_getCategoryIdByName(CategoryName)
{
	_EnterCriticalSection()
    for forCategoryID, forCategory in _share.allCategories
	{
		if (forCategory.name = CategoryName)
		{
			retval:= forCategoryID
            break
		}
	}
	_LeaveCriticalSection()
    return retval
}
_getAllCategoryIds()
{
	_EnterCriticalSection()
    allCategories:=[]
    for forCategoryID, forCategory in _share.allCategories
	{
		allCategories.push(forCategoryID)
	}
	_LeaveCriticalSection()
    return allCategories
}

_getElement(FlowID, ElementID)
{
	_EnterCriticalSection()
    element:=ObjFullyClone(_flows[FlowID].allElements[ElementID])
	_LeaveCriticalSection()
    return element
}
_setElement(FlowID, ElementID, element)
{
	_EnterCriticalSection()
    _flows[FlowID].allElements[ElementID] := ObjFullyClone(element)
	_LeaveCriticalSection()
}
_deleteElement(FlowID, ElementID)
{
	_EnterCriticalSection()
    _flows[FlowID].allElements.delete(ElementID)
	_LeaveCriticalSection()
}
_getElementProperty(FlowID, ElementID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID].allElements[ElementID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	_LeaveCriticalSection()
    return value
}
_setElementProperty(FlowID, ElementID, path, value)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID].allElements[ElementID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	_LeaveCriticalSection()
}
_deleteElementProperty(FlowID, ElementID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID].allElements[ElementID], path)
    objectPath[1].delete(objectPath[2])
	_LeaveCriticalSection()
    return value
}
_getAndIncrementElementProperty(FlowID, ElementID, path, incrementValue = 1)
{
	_EnterCriticalSection()
	_flows[FlowID].allElements[ElementID][path] += incrementValue
    value :=_flows[FlowID].allElements[ElementID][path]
	_LeaveCriticalSection()
    return value
}
_existsElement(FlowID, ElementID)
{
	_EnterCriticalSection()
    result := _flows[FlowID].allElements.haskey(ElementID)
	_LeaveCriticalSection()
    return result
}
_getAllElementIds(FlowID)
{
	_EnterCriticalSection()
    allElementIDs:=[]
    for forElementID, forElement in _flows[FlowID].allElements
	{
		allElementIDs.push(forElementID)
	}
	_LeaveCriticalSection()
    return allElementIDs
}

_getElementFromState(FlowID, ElementID, state = "")
{
	_EnterCriticalSection()
	if not state
		state := _flows[FlowID].currentState

    element:=ObjFullyClone(_flows[FlowID].states[state].allElements[ElementID])
	_LeaveCriticalSection()
    return element
}

_getConnection(FlowID, ConnectionID)
{
	_EnterCriticalSection()
    Connection:=ObjFullyClone(_flows[FlowID].allConnections[ConnectionID])
	_LeaveCriticalSection()
    return Connection
}
_setConnection(FlowID, ConnectionID, Connection)
{
	_EnterCriticalSection()
    _flows[FlowID].allConnections[ConnectionID] := ObjFullyClone(Connection)
	_LeaveCriticalSection()
}
_deleteConnection(FlowID, ConnectionID)
{
	_EnterCriticalSection()
    _flows[FlowID].allConnections.delete(ConnectionID)
	_LeaveCriticalSection()
}
_getConnectionProperty(FlowID, ConnectionID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID].allConnections[ConnectionID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	_LeaveCriticalSection()
    return value
}
_setConnectionProperty(FlowID, ConnectionID, path, value)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID].allConnections[ConnectionID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	_LeaveCriticalSection()
}
_deleteConnectionProperty(FlowID, ConnectionID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_flows[FlowID].allConnections[ConnectionID], path)
    objectPath[1].delete(objectPath[2])
	_LeaveCriticalSection()
    return value
}
_getAndIncrementConnectionProperty(FlowID, ConnectionID, path, incrementValue = 1)
{
	_EnterCriticalSection()
	_flows[FlowID].allConnections[ConnectionID][path] += incrementValue
    value :=_flows[FlowID].allConnections[ConnectionID][path]
	_LeaveCriticalSection()
    return value
}

_existsConnection(FlowID, ConnectionID)
{
	_EnterCriticalSection()
    result := _flows[FlowID].allConnections.haskey(ConnectionID)
	_LeaveCriticalSection()
    return result
}
_getAllConnectionIds(FlowID)
{
	_EnterCriticalSection()
    allConnectionIDs:=[]
    for forConnectionID, forConnection in _flows[FlowID].allConnections
	{
		allConnectionIDs.push(forConnectionID)
	}
	_LeaveCriticalSection()
    return allConnectionIDs
}

_getConnectionFromState(FlowID, ConnectionID, state = "")
{
	_EnterCriticalSection()
	if not state
		state := _flows[FlowID].currentState

    Connection:=ObjFullyClone(_flows[FlowID].states[state].allConnections[ConnectionID])
	_LeaveCriticalSection()
    return Connection
}

_getInstance(InstanceID)
{
	_EnterCriticalSection()
    instance := ObjFullyClone(_execution.instances[InstanceID])
	_LeaveCriticalSection()
    return instance
}
_setInstance(InstanceID, Instance)
{
	_EnterCriticalSection()
    _execution.instances[InstanceID] := ObjFullyClone(Instance)
	_LeaveCriticalSection()
}
_deleteInstance(InstanceID)
{
	_EnterCriticalSection()
    _execution.instances.delete(InstanceID)
	_LeaveCriticalSection()
}
_getInstanceProperty(InstanceID, path, clone = true)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
	if (clone)
    	value:=ObjFullyClone(objectPath[1][objectPath[2]])
	Else
    	value:=objectPath[1][objectPath[2]]
	_LeaveCriticalSection()
    return value
}
_setInstanceProperty(InstanceID, path, value, clone = true)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
	if (clone)
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
		objectPath[1][objectPath[2]] := value
	_LeaveCriticalSection()
}
_deleteInstanceProperty(InstanceID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
    objectPath[1].delete(objectPath[2])
	_LeaveCriticalSection()
}
_getInstancePropertyObjectIdList(InstanceID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
	result:=[]
	for key, value in objectPath[1][objectPath[2]]
	{
		result.push(key)
	}
	_LeaveCriticalSection()
	return result
}
_existsInstanceProperty(InstanceID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
    result := objectPath[1].haskey(objectPath[2])
	_LeaveCriticalSection()
    return result
}
_existsInstance(InstanceID)
{
	_EnterCriticalSection()
    result := _execution.instances.haskey(InstanceID)
	_LeaveCriticalSection()
    return result
}
_getAllInstanceIds()
{
	_EnterCriticalSection()
    allInstanceIDs:=[]
    for forInstanceID, forInstance in _execution.instances
	{
		allInstanceIDs.push(forInstanceID)
	}
	_LeaveCriticalSection()
    return allInstanceIDs
}


_getThread(InstanceID, ThreadID)
{
	_EnterCriticalSection()
    Thread := ObjFullyClone(_execution.instances[InstanceID].threads[ThreadID])
	_LeaveCriticalSection()
    return Thread
}
_setThread(InstanceID, ThreadID, Thread)
{
	_EnterCriticalSection()
    _execution.instances[InstanceID].threads[ThreadID] := ObjFullyClone(Thread)
	_LeaveCriticalSection()
}
_deleteThread(InstanceID, ThreadID)
{
	_EnterCriticalSection()
    _execution.instances[InstanceID].threads.delete(ThreadID)
	_LeaveCriticalSection()
}
_getThreadProperty(InstanceID, ThreadID, path, clone = true)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	if (clone)
    	value:=ObjFullyClone(objectPath[1][objectPath[2]])
	Else
		value:=objectPath[1][objectPath[2]]
	_LeaveCriticalSection()
    return value
}
_setThreadProperty(InstanceID, ThreadID, path, value, clone = true)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	if (clone)
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
    	objectPath[1][objectPath[2]] := value
	_LeaveCriticalSection()
}
_deleteThreadProperty(InstanceID, ThreadID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
    objectPath[1].delete(objectPath[2])
	_LeaveCriticalSection()
}
_getThreadPropertyObjectIdList(InstanceID, ThreadID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	result:=[]
	for key, value in objectPath[1][objectPath[2]]
	{
		result.push(key)
	}
	_LeaveCriticalSection()
	return result
}
_existsThreadProperty(InstanceID, ThreadID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
    result := objectPath[1].haskey(objectPath[2])
	_LeaveCriticalSection()
    return result
}
_existsThread(InstanceID, ThreadID)
{
	_EnterCriticalSection()
    result := _execution.instances[InstanceID].threads.haskey(ThreadID)
	_LeaveCriticalSection()
    return result
}
_getAllThreadIds(InstanceID)
{
	_EnterCriticalSection()
    allThreadIDs:=[]
    for forThreadID, forThread in _execution.instances[InstanceID].threads
	{
		allThreadIDs.push(forThreadID)
	}
	_LeaveCriticalSection()
    return allThreadIDs
}


_getTrigger(TriggerID)
{
	_EnterCriticalSection()
    Trigger := ObjFullyClone(_execution.Triggers[TriggerID])
	_LeaveCriticalSection()
    return Trigger
}
_setTrigger(TriggerID, Trigger)
{
	_EnterCriticalSection()
    _execution.Triggers[TriggerID] := ObjFullyClone(Trigger)
	_LeaveCriticalSection()
}
_deleteTrigger(TriggerID)
{
	_EnterCriticalSection()
    _execution.Triggers.delete(TriggerID)
	_LeaveCriticalSection()
}
_getTriggerProperty(TriggerID, path)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.Triggers[TriggerID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	_LeaveCriticalSection()
    return value
}
_setTriggerProperty(TriggerID, path, value)
{
	_EnterCriticalSection()
    objectPath:=parseObjectPath(_execution.Triggers[TriggerID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	_LeaveCriticalSection()
}
_existsTrigger(TriggerID)
{
	_EnterCriticalSection()
    result := _execution.Triggers.haskey(TriggerID)
	_LeaveCriticalSection()
    return result
}
_getAllTriggerIds()
{
	_EnterCriticalSection()
    allTriggerIDs:=[]
    for forTriggerID, forTrigger in _execution.Triggers
	{
		allTriggerIDs.push(forTriggerID)
	}
	_LeaveCriticalSection()
    return allTriggerIDs
}



parseObjectPath(obj, path)
{
    loop,parse,path,% "."
    {
        lastPathPart:=A_LoopField
        objLast:=obj
        obj:=obj[A_LoopField]
    }
    return [objLast, lastPathPart]
}