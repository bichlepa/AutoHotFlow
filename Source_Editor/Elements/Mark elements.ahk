;mark an element or connection. If parameter additional is true, mark it additionally to others
MarkOne(p_ID,additional:=false)
{
	
	EnterCriticalSection(_cs_shared)
	
	;~ ToolTip,% p_id " - " additional
	if (p_ID!="")
	{
		if (additional=false)
		{
			UnmarkEverything(false)
			
			;Mark one element
			if p_ID contains connection
			{
				_setConnectionProperty(FlowID, p_ID, "marked", true)
			}
			else
			{
				_setElementProperty(FlowID, p_ID, "marked", true)
			}
			
			
		}
		else ;if (additional=true)
		{
			if p_ID contains connection
			{
				_setConnectionProperty(FlowID, p_ID, "marked", !_getConnectionProperty(FlowID, p_ID, "marked"))
			}
			else
			{
				_setElementProperty(FlowID, p_ID, "marked", !_getElementProperty(FlowID, p_ID, "marked"))
			}
			
			
		}
		
		CreateMarkedList()
		
		;~ ToolTip("-" p_ID "-" tempList[p_ID].marked "-" markedElement )
		;~ ui_UpdateStatusbartext()
	}

	LeaveCriticalSection(_cs_shared)
}

;Unmark all elements and connections
UnmarkEverything(CreateList=true)
{
	global _flows 
	global FlowID 
	
	EnterCriticalSection(_cs_shared)
	
	for forIndex, forElementID in _getAllElementIds(FlowID) ;Add all marked elements into array
	{
		_setElementProperty(FlowID, forElementID, "marked", false)
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all marked elements into array
	{
		_setConnectionProperty(FlowID, forConnectionID, "marked", false)
	}
	
	if (CreateList)
		CreateMarkedList()
	;~ ui_UpdateStatusbartext()
	
	LeaveCriticalSection(_cs_shared)
}

MarkEverything()
{
	global _flows
	global FlowID
	
	EnterCriticalSection(_cs_shared)
	
	for forIndex, forElementID in _getAllElementIds(FlowID) ;Add all marked elements into array
	{
		_setElementProperty(FlowID, forElementID, "marked", true)
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all marked elements into array
	{
		_setConnectionProperty(FlowID, forConnectionID, "marked", false)
	}
	
	CreateMarkedList()
	
	;~ ui_UpdateStatusbartext()	
	
	LeaveCriticalSection(_cs_shared)
}

CreateMarkedList()
{
	EnterCriticalSection(_cs_shared)
	
	markedElements:=[]

	for forIndex, forElementID in _getAllElementIds(FlowID) ;Add all marked elements into array
	{
		if (_getElementProperty(FlowID, forElementID, "marked"))
			markedElements[forElementID]:=forElementID
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all marked elements into array
	{
		if (_getConnectionProperty(FlowID, forConnectionID, "marked"))
			markedElements[forConnectionID]:=forConnectionID
	}
	
	if (markedElements.count()=1)
	{
		for forID, forID2 in markedElements
		{
			_setFlowProperty(FlowID, "markedElement", forID)
		}
	}
	else
	{
		;~ ToolTip no element
		_setFlowProperty(FlowID, "markedElement", "")
	}
	
	_setFlowProperty(FlowID, "markedElements", markedElements)
	LeaveCriticalSection(_cs_shared)
}