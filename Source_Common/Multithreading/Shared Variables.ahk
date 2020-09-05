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
_getAndIncrementShared(path)
{
	EnterCriticalSection(_cs_shared)
    value:=_share[path]++
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
_existsFlow(FlowID)
{
	EnterCriticalSection(_cs_shared)
    result := _flows.haskey(FlowID)
	LeaveCriticalSection(_cs_shared)
    return result
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



parseObjectPath(obj, path)
{
    loop,parse,path,% "."
    {
        lastPathElement:=A_LoopField
        objLast:=obj
        obj:=obj[A_LoopField]
    }
    return [objLast, lastPathElement]
}