;mark an element or connection. If parameter additional is true, mark it additionally to others
SelectOneItem(p_ID,additional:=false)
{
	
	_EnterCriticalSection()
	
	;~ ToolTip,% p_id " - " additional
	if (p_ID!="")
	{
		if (additional=false)
		{
			UnSelectEverything(false)
			
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
		
		UpdateSelectedItemsList()
		
		;~ ToolTip("-" p_ID "-" tempList[p_ID].marked "-" selectedElement )
		;~ ui_UpdateStatusbartext()
	}

	_LeaveCriticalSection()
}

;Unmark all elements and connections
UnSelectEverything(CreateList=true)
{
	_EnterCriticalSection()
	
	for forIndex, forElementID in _getAllElementIds(FlowID) ;Add all marked elements into array
	{
		_setElementProperty(FlowID, forElementID, "marked", false)
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all marked elements into array
	{
		_setConnectionProperty(FlowID, forConnectionID, "marked", false)
	}
	
	if (CreateList)
		UpdateSelectedItemsList()
	;~ ui_UpdateStatusbartext()
	
	_LeaveCriticalSection()
}

SelectEverything()
{
	_EnterCriticalSection()
	
	for forIndex, forElementID in _getAllElementIds(FlowID) ;Add all marked elements into array
	{
		_setElementProperty(FlowID, forElementID, "marked", true)
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all marked elements into array
	{
		_setConnectionProperty(FlowID, forConnectionID, "marked", false)
	}
	
	UpdateSelectedItemsList()
	
	;~ ui_UpdateStatusbartext()	
	
	_LeaveCriticalSection()
}

UpdateSelectedItemsList()
{
	_EnterCriticalSection()
	
	selectedElements:=[]

	for forIndex, forElementID in _getAllElementIds(FlowID) ;Add all marked elements into array
	{
		if (_getElementProperty(FlowID, forElementID, "marked"))
			selectedElements[forElementID]:=forElementID
	}
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) ;Add all marked elements into array
	{
		if (_getConnectionProperty(FlowID, forConnectionID, "marked"))
			selectedElements[forConnectionID]:=forConnectionID
	}
	
	if (selectedElements.count()=1)
	{
		for forID, forID2 in selectedElements
		{
			_setFlowProperty(FlowID, "selectedElement", forID)
		}
	}
	else
	{
		;~ ToolTip no element
		_setFlowProperty(FlowID, "selectedElement", "")
	}
	
	_setFlowProperty(FlowID, "selectedElements", selectedElements)
	_LeaveCriticalSection()
}