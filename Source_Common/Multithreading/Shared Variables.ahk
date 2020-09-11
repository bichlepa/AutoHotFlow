;This module contains the access function for all shared data between the ahk-Threads
;There are a few other functions which can access the shared data, too:
;x_TriggerInNewAHKThread
;x_ExecuteInNewAHKThread

_setShared(path, value)
{
	EnterCriticalSection(_cs_shared)
    _share[path] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_getShared(path)
{
	EnterCriticalSection(_cs_shared)
    value:=ObjFullyClone(_share[path])
	LeaveCriticalSection(_cs_shared)
    return value
}
_getSharedProperty(path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share, path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setSharedProperty(path, value, clone = true)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share, path)
	if (clone)
	{
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	}
	Else
	{
    	objectPath[1][objectPath[2]] := value
	}
	LeaveCriticalSection(_cs_shared)
}
_getAndIncrementShared(path, incrementValue = 1)
{
	EnterCriticalSection(_cs_shared)
    _share[path] += incrementValue
    value:=_share[path]
	LeaveCriticalSection(_cs_shared)
    return value
}
_appendToShared(path, appendValue)
{
	EnterCriticalSection(_cs_shared)
    _share[path] .= appendValue
	LeaveCriticalSection(_cs_shared)
}
_getAllSharedKeys()
{
	EnterCriticalSection(_cs_shared)
    allKeys:=[]
    for forKey, forValue in _share
	{
		allKeys.push(forKey)
	}
	LeaveCriticalSection(_cs_shared)
    return allKeys
}


_setSettings(path, value)
{
	EnterCriticalSection(_cs_shared)
    _settings[path] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_getSettings(path)
{
	EnterCriticalSection(_cs_shared)
    value:=ObjFullyClone(_settings[path])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setTask(path, value)
{
	EnterCriticalSection(_cs_shared)
    _share[path].Tasks.push(value)
	LeaveCriticalSection(_cs_shared)
}
_getTask(path)
{
	EnterCriticalSection(_cs_shared)
    value:=_share[path].Tasks.removeat(1)
	LeaveCriticalSection(_cs_shared)
    return value
}


_getFlow(FlowID)
{
	EnterCriticalSection(_cs_shared)
    flow:=ObjFullyClone(_flows[FlowID])
	LeaveCriticalSection(_cs_shared)
    return flow
}
_setFlow(FlowID, flow)
{
	EnterCriticalSection(_cs_shared)
    _flows[FlowID] := ObjFullyClone(flow)
	LeaveCriticalSection(_cs_shared)
}
_deleteFlow(FlowID)
{
	EnterCriticalSection(_cs_shared)
    _flows.delete(FlowID)
	LeaveCriticalSection(_cs_shared)
}
_getFlowProperty(FlowID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setFlowProperty(FlowID, path, value, clone = true)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID], path)
	if (clone)
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
		objectPath[1][objectPath[2]] := value
	LeaveCriticalSection(_cs_shared)
}
_deleteFlowProperty(FlowID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID], path)
    objectPath[1].delete(objectPath[2])
	LeaveCriticalSection(_cs_shared)
    return value
}
_getAndIncrementFlowProperty(FlowID, path)
{
	EnterCriticalSection(_cs_shared)
    value:=++_flows[FlowID][path]
	LeaveCriticalSection(_cs_shared)
    return value
}
_existsFlow(FlowID)
{
	EnterCriticalSection(_cs_shared)
    result := _flows.haskey(FlowID)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getFlowIdByName(FlowName)
{
	EnterCriticalSection(_cs_shared)
    for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = FlowName)
		{
			retval:= forFlowID
            break
		}
	}
	LeaveCriticalSection(_cs_shared)
    return retval
}
_getAllFlowIds()
{
	EnterCriticalSection(_cs_shared)
    allFlows:=[]
    for forFlowID, forFlow in _Flows
	{
		allFlows.push(forFlowID)
	}
	LeaveCriticalSection(_cs_shared)
    return allFlows
}
_getAllFlowPropertyKeys(FlowID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID], path)
    allKeys:=[]
    for forKey, forValue in objectPath[1][objectPath[2]]
	{
		allKeys.push(forKey)
	}
	LeaveCriticalSection(_cs_shared)
    return allKeys
}

_getCategory(CategoryId)
{
	EnterCriticalSection(_cs_shared)
    category:=ObjFullyClone(_share.allCategories[CategoryId])
	LeaveCriticalSection(_cs_shared)
    return category
}
_setCategory(CategoryId, newCategory)
{
	EnterCriticalSection(_cs_shared)
    _share.allCategories[CategoryId] := ObjFullyClone(newCategory)
	LeaveCriticalSection(_cs_shared)
}
_deleteCategory(CategoryId)
{
	EnterCriticalSection(_cs_shared)
    _share.allCategories.delete(CategoryId)
	LeaveCriticalSection(_cs_shared)
}
_getCategoryProperty(CategoryId, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share.allCategories[CategoryId], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setCategoryProperty(CategoryId, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share.allCategories[CategoryId], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_existsCategory(CategoryId)
{
	EnterCriticalSection(_cs_shared)
    result := _share.allCategories.haskey(CategoryId)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getCategoryIdByName(CategoryName)
{
	EnterCriticalSection(_cs_shared)
    for forCategoryID, forCategory in _share.allCategories
	{
		if (forCategory.name = CategoryName)
		{
			retval:= forCategoryID
            break
		}
	}
	LeaveCriticalSection(_cs_shared)
    return retval
}
_getAllCategoryIds()
{
	EnterCriticalSection(_cs_shared)
    allCategories:=[]
    for forCategoryID, forCategory in _share.allCategories
	{
		allCategories.push(forCategoryID)
	}
	LeaveCriticalSection(_cs_shared)
    return allCategories
}

_getElement(FlowID, ElementID)
{
	EnterCriticalSection(_cs_shared)
    element:=ObjFullyClone(_flows[FlowID].allElements[ElementID])
	LeaveCriticalSection(_cs_shared)
    return element
}
_setElement(FlowID, ElementID, element)
{
	EnterCriticalSection(_cs_shared)
    _flows[FlowID].allElements[ElementID] := ObjFullyClone(element)
	LeaveCriticalSection(_cs_shared)
}
_deleteElement(FlowID, ElementID)
{
	EnterCriticalSection(_cs_shared)
    _flows[FlowID].allElements.delete(ElementID)
	LeaveCriticalSection(_cs_shared)
}
_getElementProperty(FlowID, ElementID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID].allElements[ElementID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setElementProperty(FlowID, ElementID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID].allElements[ElementID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_deleteElementProperty(FlowID, ElementID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID].allElements[ElementID], path)
    objectPath[1].delete(objectPath[2])
	LeaveCriticalSection(_cs_shared)
    return value
}
_getAndIncrementElementProperty(FlowID, ElementID, path, incrementValue = 1)
{
	EnterCriticalSection(_cs_shared)
	_flows[FlowID].allElements[ElementID][path] += incrementValue
    value :=_flows[FlowID].allElements[ElementID][path]
	LeaveCriticalSection(_cs_shared)
    return value
}
_existsElement(FlowID, ElementID)
{
	EnterCriticalSection(_cs_shared)
    result := _flows[FlowID].allElements.haskey(ElementID)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getAllElementIds(FlowID)
{
	EnterCriticalSection(_cs_shared)
    allElementIDs:=[]
    for forElementID, forElement in _flows[FlowID].allElements
	{
		allElementIDs.push(forElementID)
	}
	LeaveCriticalSection(_cs_shared)
    return allElementIDs
}

_getElementFromState(FlowID, ElementID, state = "")
{
	EnterCriticalSection(_cs_shared)
	if not state
		state := _flows[FlowID].currentState

    element:=ObjFullyClone(_flows[FlowID].states[state].allElements[ElementID])
	LeaveCriticalSection(_cs_shared)
    return element
}

_getConnection(FlowID, ConnectionID)
{
	EnterCriticalSection(_cs_shared)
    Connection:=ObjFullyClone(_flows[FlowID].allConnections[ConnectionID])
	LeaveCriticalSection(_cs_shared)
    return Connection
}
_setConnection(FlowID, ConnectionID, Connection)
{
	EnterCriticalSection(_cs_shared)
    _flows[FlowID].allConnections[ConnectionID] := ObjFullyClone(Connection)
	LeaveCriticalSection(_cs_shared)
}
_deleteConnection(FlowID, ConnectionID)
{
	EnterCriticalSection(_cs_shared)
    _flows[FlowID].allConnections.delete(ConnectionID)
	LeaveCriticalSection(_cs_shared)
}
_getConnectionProperty(FlowID, ConnectionID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID].allConnections[ConnectionID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setConnectionProperty(FlowID, ConnectionID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID].allConnections[ConnectionID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_deleteConnectionProperty(FlowID, ConnectionID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID].allConnections[ConnectionID], path)
    objectPath[1].delete(objectPath[2])
	LeaveCriticalSection(_cs_shared)
    return value
}
_getAndIncrementConnectionProperty(FlowID, ConnectionID, path, incrementValue = 1)
{
	EnterCriticalSection(_cs_shared)
	_flows[FlowID].allConnections[ConnectionID][path] += incrementValue
    value :=_flows[FlowID].allConnections[ConnectionID][path]
	LeaveCriticalSection(_cs_shared)
    return value
}

_existsConnection(FlowID, ConnectionID)
{
	EnterCriticalSection(_cs_shared)
    result := _flows[FlowID].allConnections.haskey(ConnectionID)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getAllConnectionIds(FlowID)
{
	EnterCriticalSection(_cs_shared)
    allConnectionIDs:=[]
    for forConnectionID, forConnection in _flows[FlowID].allConnections
	{
		allConnectionIDs.push(forConnectionID)
	}
	LeaveCriticalSection(_cs_shared)
    return allConnectionIDs
}

_getConnectionFromState(FlowID, ConnectionID, state = "")
{
	EnterCriticalSection(_cs_shared)
	if not state
		state := _flows[FlowID].currentState

    Connection:=ObjFullyClone(_flows[FlowID].states[state].allConnections[ConnectionID])
	LeaveCriticalSection(_cs_shared)
    return Connection
}

_getInstance(InstanceID)
{
	EnterCriticalSection(_cs_shared)
    instance := ObjFullyClone(_execution.instances[InstanceID])
	LeaveCriticalSection(_cs_shared)
    return instance
}
_setInstance(InstanceID, Instance)
{
	EnterCriticalSection(_cs_shared)
    _execution.instances[InstanceID] := ObjFullyClone(Instance)
	LeaveCriticalSection(_cs_shared)
}
_deleteInstance(InstanceID)
{
	EnterCriticalSection(_cs_shared)
    _execution.instances.delete(InstanceID)
	LeaveCriticalSection(_cs_shared)
}
_getInstanceProperty(InstanceID, path, clone = true)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
	if (clone)
    	value:=ObjFullyClone(objectPath[1][objectPath[2]])
	Else
    	value:=objectPath[1][objectPath[2]]
	LeaveCriticalSection(_cs_shared)
    return value
}
_setInstanceProperty(InstanceID, path, value, clone = true)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
	if (clone)
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
		objectPath[1][objectPath[2]] := value
	LeaveCriticalSection(_cs_shared)
}
_deleteInstanceProperty(InstanceID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
    objectPath[1].delete(objectPath[2])
	LeaveCriticalSection(_cs_shared)
}
_getInstancePropertyObjectIdList(InstanceID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
	result:=[]
	for key, value in objectPath[1][objectPath[2]]
	{
		result.push(key)
	}
	LeaveCriticalSection(_cs_shared)
	return result
}
_existsInstanceProperty(InstanceID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
    result := objectPath[1].haskey(objectPath[2])
	LeaveCriticalSection(_cs_shared)
    return result
}
_existsInstance(InstanceID)
{
	EnterCriticalSection(_cs_shared)
    result := _execution.instances.haskey(InstanceID)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getAllInstanceIds()
{
	EnterCriticalSection(_cs_shared)
    allInstanceIDs:=[]
    for forInstanceID, forInstance in _execution.instances
	{
		allInstanceIDs.push(forInstanceID)
	}
	LeaveCriticalSection(_cs_shared)
    return allInstanceIDs
}


_getThread(InstanceID, ThreadID)
{
	EnterCriticalSection(_cs_shared)
    Thread := ObjFullyClone(_execution.instances[InstanceID].threads[ThreadID])
	LeaveCriticalSection(_cs_shared)
    return Thread
}
_setThread(InstanceID, ThreadID, Thread)
{
	EnterCriticalSection(_cs_shared)
    _execution.instances[InstanceID].threads[ThreadID] := ObjFullyClone(Thread)
	LeaveCriticalSection(_cs_shared)
}
_deleteThread(InstanceID, ThreadID)
{
	EnterCriticalSection(_cs_shared)
    _execution.instances[InstanceID].threads.delete(ThreadID)
	LeaveCriticalSection(_cs_shared)
}
_getThreadProperty(InstanceID, ThreadID, path, clone = true)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	if (clone)
    	value:=ObjFullyClone(objectPath[1][objectPath[2]])
	Else
		value:=objectPath[1][objectPath[2]]
	LeaveCriticalSection(_cs_shared)
    return value
}
_setThreadProperty(InstanceID, ThreadID, path, value, clone = true)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	if (clone)
    	objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
    	objectPath[1][objectPath[2]] := value
	LeaveCriticalSection(_cs_shared)
}
_deleteThreadProperty(InstanceID, ThreadID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
    objectPath[1].delete(objectPath[2])
	LeaveCriticalSection(_cs_shared)
}
_getThreadPropertyObjectIdList(InstanceID, ThreadID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	result:=[]
	for key, value in objectPath[1][objectPath[2]]
	{
		result.push(key)
	}
	LeaveCriticalSection(_cs_shared)
	return result
}
_existsThreadProperty(InstanceID, ThreadID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
    result := objectPath[1].haskey(objectPath[2])
	LeaveCriticalSection(_cs_shared)
    return result
}
_existsThread(InstanceID, ThreadID)
{
	EnterCriticalSection(_cs_shared)
    result := _execution.instances[InstanceID].threads.haskey(ThreadID)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getAllThreadIds(InstanceID)
{
	EnterCriticalSection(_cs_shared)
    allThreadIDs:=[]
    for forThreadID, forThread in _execution.instances[InstanceID].threads
	{
		allThreadIDs.push(forThreadID)
	}
	LeaveCriticalSection(_cs_shared)
    return allThreadIDs
}


_getTrigger(TriggerID)
{
	EnterCriticalSection(_cs_shared)
    Trigger := ObjFullyClone(_execution.Triggers[TriggerID])
	LeaveCriticalSection(_cs_shared)
    return Trigger
}
_setTrigger(TriggerID, Trigger)
{
	EnterCriticalSection(_cs_shared)
    _execution.Triggers[TriggerID] := ObjFullyClone(Trigger)
	LeaveCriticalSection(_cs_shared)
}
_deleteTrigger(TriggerID)
{
	EnterCriticalSection(_cs_shared)
    _execution.Triggers.delete(TriggerID)
	LeaveCriticalSection(_cs_shared)
}
_getTriggerProperty(TriggerID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.Triggers[TriggerID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setTriggerProperty(TriggerID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.Triggers[TriggerID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_existsTrigger(TriggerID)
{
	EnterCriticalSection(_cs_shared)
    result := _execution.Triggers.haskey(TriggerID)
	LeaveCriticalSection(_cs_shared)
    return result
}
_getAllTriggerIds()
{
	EnterCriticalSection(_cs_shared)
    allTriggerIDs:=[]
    for forTriggerID, forTrigger in _execution.Triggers
	{
		allTriggerIDs.push(forTriggerID)
	}
	LeaveCriticalSection(_cs_shared)
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