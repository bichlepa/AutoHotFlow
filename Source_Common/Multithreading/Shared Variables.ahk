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
_setSharedProperty(path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share, path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
}
_getAndIncrementShared(path)
{
	EnterCriticalSection(_cs_shared)
    value:=++_share[path]
	LeaveCriticalSection(_cs_shared)
    return value
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
_setFlowProperty(FlowID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_flows[FlowID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
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

_getCategory(categoryid)
{
	EnterCriticalSection(_cs_shared)
    category:=ObjFullyClone(_share.allCategories[categoryid])
	LeaveCriticalSection(_cs_shared)
    return category
}
_setCategory(categoryid, newCategory)
{
	EnterCriticalSection(_cs_shared)
    _share.allCategories[categoryid] := ObjFullyClone(newCategory)
	LeaveCriticalSection(_cs_shared)
}
_deleteCategory(categoryid)
{
	EnterCriticalSection(_cs_shared)
    _share.allCategories.delete(categoryid)
	LeaveCriticalSection(_cs_shared)
}
_getCategoryProperty(FlowID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share.allCategories[categoryid], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setCategoryProperty(FlowID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_share.allCategories[categoryid], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
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
_existsConnection(FlowID, ConnectionID)
{
	EnterCriticalSection(_cs_shared)
    result := _flows[FlowID].allConnections.haskey(ConnectionID)
	LeaveCriticalSection(_cs_shared)
    return result
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
_getInstanceProperty(InstanceID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setInstanceProperty(InstanceID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
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
_getThreadProperty(InstanceID, ThreadID, path)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
    value:=ObjFullyClone(objectPath[1][objectPath[2]])
	LeaveCriticalSection(_cs_shared)
    return value
}
_setThreadProperty(InstanceID, ThreadID, path, value)
{
	EnterCriticalSection(_cs_shared)
    objectPath:=parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
    objectPath[1][objectPath[2]] := ObjFullyClone(value)
	LeaveCriticalSection(_cs_shared)
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